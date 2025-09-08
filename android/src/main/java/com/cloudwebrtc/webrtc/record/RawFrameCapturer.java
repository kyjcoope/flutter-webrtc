package com.cloudwebrtc.webrtc.record;

import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import org.webrtc.VideoFrame;
import org.webrtc.VideoSink;
import org.webrtc.VideoTrack;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Grabs raw frames from a VideoTrack, converts to tightly-packed I420 (YUV420 planar),
 * and pushes them into the native ring buffer through JNI.
 */
public class RawFrameCapturer implements VideoSink {
    private static final String TAG = "RawFrameCapturer";

    // Native ring buffer config
    private static final int DEFAULT_CAPACITY = 16; // number of frames to buffer
    private static final int FRAME_TYPE_RAW = 1;     // raw (uncompressed)
    private static final int PIXEL_TYPE_I420 = 1;    // I420 (YUV420 planar)

    private static native int initNativeBuffer(String trackId, int capacity, int bufferSize);
    private static native long pushFrame(String trackId,
                                         java.nio.ByteBuffer buffer,
                                         int width,
                                         int height,
                                         long frameTimeMs,
                                         int rotation,
                                         int frameType,
                                         int codecOrPixelType);
    private static native void freeNativeBuffer(String trackId);

    private final VideoTrack videoTrack;
    private final String trackId;

    private final AtomicBoolean stopped = new AtomicBoolean(false);
    private boolean nativeInited = false;

    private long frameCounter = 0;
    private int lastWidth = 0;
    private int lastHeight = 0;
    private int lastBufferSize = 0;
    private ByteBuffer reusableBuffer; // direct buffer for packed I420

    public RawFrameCapturer(VideoTrack track) {
        this.videoTrack = track;
        this.trackId = safeTrackId();
        this.videoTrack.addSink(this);
        Log.d(TAG, "Started raw frame capture for track: " + trackId);
    }

    public void stop() {
        if (!stopped.compareAndSet(false, true)) return;

        // Detach sink from main thread
        if (Looper.myLooper() == Looper.getMainLooper()) {
            videoTrack.removeSink(this);
        } else {
            new Handler(Looper.getMainLooper()).post(() -> {
                try {
                    videoTrack.removeSink(this);
                } catch (Exception ignore) {}
            });
        }

        // Free native resources
        if (nativeInited) {
            try {
                freeNativeBuffer(trackId);
            } catch (Throwable t) {
                Log.w(TAG, "freeNativeBuffer failed: " + t.getMessage(), t);
            } finally {
                nativeInited = false;
            }
        }

        reusableBuffer = null;
        Log.d(TAG, "Stopped raw frame capture for track: " + trackId);
    }

    @Override
    public void onFrame(VideoFrame frame) {
        if (stopped.get()) return;

        frame.retain();
        try {
            final VideoFrame.Buffer buffer = frame.getBuffer();
            final VideoFrame.I420Buffer i420 = buffer.toI420();
            try {
                final int width = i420.getWidth();
                final int height = i420.getHeight();

                // Allocate or reallocate native ring buffer when size changes
                final int packedSize = packedI420Size(width, height);
                if (!nativeInited || width != lastWidth || height != lastHeight || packedSize != lastBufferSize) {
                    reinitNative(width, height, packedSize);
                }

                // Ensure a direct ByteBuffer large enough for tightly-packed I420
                if (reusableBuffer == null || reusableBuffer.capacity() < packedSize) {
                    reusableBuffer = ByteBuffer.allocateDirect(packedSize).order(ByteOrder.nativeOrder());
                }
                reusableBuffer.clear();

                // Pack planes into tightly-packed I420 (no padding)
                packI420(i420, reusableBuffer);

                frameCounter++;
                final long tsMs = frame.getTimestampNs() / 1_000_000L;
                final int rotation = frame.getRotation();

                // Push into native ring buffer
                long seq = pushFrame(
                        trackId,
                        reusableBuffer,
                        width,
                        height,
                        tsMs,
                        rotation,
                        FRAME_TYPE_RAW,
                        PIXEL_TYPE_I420
                );

                Log.d(TAG, "pushFrame #" + frameCounter +
                        " seq=" + seq +
                        " track=" + trackId +
                        " size=" + width + "x" + height +
                        " rot=" + rotation +
                        " tsMs=" + tsMs +
                        " bytes=" + packedSize);

            } catch (Exception e) {
                Log.e(TAG, "Error packing/pushing frame: " + e.getMessage(), e);
            } finally {
                i420.release();
            }
        } catch (Throwable t) {
            Log.e(TAG, "Error processing frame: " + t.getMessage(), t);
        } finally {
            frame.release();
        }
    }

    private void reinitNative(int width, int height, int bufferSize) {
        // Recreate native buffer with the new size
        if (nativeInited) {
            try { freeNativeBuffer(trackId); } catch (Throwable ignore) {}
            nativeInited = false;
        }
        try {
            int ok = initNativeBuffer(trackId, DEFAULT_CAPACITY, bufferSize);
            if (ok != 0) {
                Log.w(TAG, "initNativeBuffer returned non-zero: " + ok);
            }
            nativeInited = true;
            lastWidth = width;
            lastHeight = height;
            lastBufferSize = bufferSize;
            Log.d(TAG, "initNativeBuffer(track=" + trackId + ", capacity=" + DEFAULT_CAPACITY +
                    ", bufferSize=" + bufferSize + ") for " + width + "x" + height);
        } catch (Throwable t) {
            Log.e(TAG, "initNativeBuffer failed: " + t.getMessage(), t);
        }
    }

    private static int packedI420Size(int width, int height) {
        final int chromaW = (width + 1) / 2;
        final int chromaH = (height + 1) / 2;
        return width * height + chromaW * chromaH * 2;
    }

    private static void packI420(VideoFrame.I420Buffer i420, ByteBuffer out) {
        final int width = i420.getWidth();
        final int height = i420.getHeight();
        final int chromaW = (width + 1) / 2;
        final int chromaH = (height + 1) / 2;

        copyPlaneSafe(i420.getDataY(), i420.getStrideY(), width, height, out, "Y");
        copyPlaneSafe(i420.getDataU(), i420.getStrideU(), chromaW, chromaH, out, "U");
        copyPlaneSafe(i420.getDataV(), i420.getStrideV(), chromaW, chromaH, out, "V");
        out.flip();
    }

    private static void copyPlaneSafe(ByteBuffer src,
                                      int srcStride,
                                      int width,
                                      int height,
                                      ByteBuffer dst,
                                      String label) {
        // Some implementations may have srcStride < width (shouldn’t, but guard) or
        // buffer limit smaller than expected due to cropping. Clamp row copy size.
        final int rowBytes = Math.min(width, srcStride);
        final int requiredBytes = (height - 1) * srcStride + rowBytes;

        int available = src.capacity();
        // Use duplicate to ignore current position/limit.
        for (int row = 0; row < height; row++) {
            int srcPos = row * srcStride;
            int end = srcPos + rowBytes;
            if (end > available) {
                // Abort on unexpected short buffer to avoid IllegalArgumentException.
                Log.w(TAG, "copyPlaneSafe(" + label + ") abort: row=" + row +
                        " srcPos=" + srcPos + " end=" + end + " cap=" + available);
                break;
            }
            ByteBuffer rowBuf = src.duplicate();
            // Ensure full visibility (some buffers come with non-zero position/limit)
            rowBuf.position(0);
            rowBuf.limit(available);
            rowBuf.position(srcPos);
            rowBuf.limit(end);
            dst.put(rowBuf);
        }

        int written = rowBytes * height;
        if (written < width * height && "Y".equals(label)) {
            Log.w(TAG, "copyPlaneSafe: wrote fewer luma bytes than expected (" +
                    written + " < " + (width * height) + ")");
        }
    }

    private String safeTrackId() {
        try {
            return videoTrack == null ? "<null>" : videoTrack.id();
        } catch (Exception e) {
            return "<unknown>";
        }
    }
}