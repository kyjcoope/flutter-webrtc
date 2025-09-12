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

public class FrameStreamer implements VideoSink {
    private static final String TAG = "FrameStreamer";

    private static final int DEFAULT_CAPACITY = 16;
    private static final int COLOR_FORMAT_I420 = 1;

    private static native int initNativeBuffer(String trackId, int capacity, int bufferSize);
    private static native int pushFrame(String trackId,
                                        ByteBuffer buffer,
                                        int dataSize,
                                        int width,
                                        int height,
                                        long frameTimeMs,
                                        int rotation,
                                        int colorFormat);
    private static native void freeNativeBuffer(String trackId);

    private final VideoTrack videoTrack;
    private final String trackId;

    private final AtomicBoolean stopped = new AtomicBoolean(false);
    private boolean nativeInited = false;

    private long frameCounter = 0;
    private int lastWidth = 0;
    private int lastHeight = 0;
    private int lastBufferSize = 0;
    private ByteBuffer reusableBuffer;

    public FrameStreamer(VideoTrack track) {
        this.videoTrack = track;
        this.trackId = safeTrackId();
        this.videoTrack.addSink(this);
        Log.d(TAG, "Started frame streaming for track: " + trackId);
    }

    public void stop() {
        if (!stopped.compareAndSet(false, true)) return;
        if (Looper.myLooper() == Looper.getMainLooper()) {
            videoTrack.removeSink(this);
        } else {
            new Handler(Looper.getMainLooper()).post(() -> {
                try { videoTrack.removeSink(this); } catch (Exception ignore) {}
            });
        }
        if (nativeInited) {
            try { freeNativeBuffer(trackId); } catch (Throwable t) {
                Log.w(TAG, "freeNativeBuffer failed: " + t.getMessage());
            }
            nativeInited = false;
        }
        reusableBuffer = null;
        Log.d(TAG, "Stopped frame streaming for track: " + trackId);
    }

    @Override
    public void onFrame(VideoFrame frame) {
        if (stopped.get()) return;
        frame.retain();
        try {
            VideoFrame.Buffer buf = frame.getBuffer();
            VideoFrame.I420Buffer i420 = buf.toI420();
            try {
                int w = i420.getWidth();
                int h = i420.getHeight();
                int size = packedI420Size(w, h);

                if (!nativeInited || w != lastWidth || h != lastHeight || size != lastBufferSize) {
                    reinitNative(w, h, size);
                }

                if (reusableBuffer == null || reusableBuffer.capacity() < size) {
                    reusableBuffer = ByteBuffer.allocateDirect(size).order(ByteOrder.nativeOrder());
                }
                reusableBuffer.clear();

                packI420(i420, reusableBuffer);

                long tsMs = frame.getTimestampNs() / 1_000_000L;
                int rot = frame.getRotation();

                int ok = pushFrame(trackId, reusableBuffer, size, w, h, tsMs, rot, COLOR_FORMAT_I420);
                frameCounter++;
                if (ok == 0) {
                    Log.w(TAG, "pushFrame failed for #" + frameCounter);
                } else {
                    Log.d(TAG, "pushed #" + frameCounter + " size=" + w + "x" + h + " bytes=" + size);
                }
            } finally {
                i420.release();
            }
        } catch (Exception e) {
            Log.e(TAG, "Error processing frame: " + e.getMessage(), e);
        } finally {
            frame.release();
        }
    }

    private void reinitNative(int w, int h, int bufferSize) {
        if (nativeInited) {
            try { freeNativeBuffer(trackId); } catch (Throwable ignore) {}
            nativeInited = false;
        }
        int res = initNativeBuffer(trackId, DEFAULT_CAPACITY, bufferSize);
        Log.d(TAG, "initNativeBuffer(track=" + trackId + ", cap=" + DEFAULT_CAPACITY + ", buf=" + bufferSize + ") => " + res);
        nativeInited = res != 0;
        lastWidth = w;
        lastHeight = h;
        lastBufferSize = bufferSize;
    }

    private static int packedI420Size(int w, int h) {
        int cw = (w + 1) / 2;
        int ch = (h + 1) / 2;
        return w * h + cw * ch * 2;
    }

    private static void packI420(VideoFrame.I420Buffer i420, ByteBuffer out) {
        int w = i420.getWidth();
        int h = i420.getHeight();
        int cw = (w + 1) / 2;
        int ch = (h + 1) / 2;
        copyPlaneAbs(i420.getDataY(), i420.getStrideY(), w, h, out);
        copyPlaneAbs(i420.getDataU(), i420.getStrideU(), cw, ch, out);
        copyPlaneAbs(i420.getDataV(), i420.getStrideV(), cw, ch, out);
        out.flip();
    }

    private static void copyPlaneAbs(ByteBuffer src, int stride, int pw, int ph, ByteBuffer dst) {
        int cap = src.capacity();
        int copyCols = Math.min(stride, pw);
        for (int row = 0; row < ph; row++) {
            int rowStart = row * stride;
            if (rowStart >= cap) {
                int remain = (ph - row) * pw;
                for (int i = 0; i < remain; i++) dst.put((byte)0);
                return;
            }
            int available = cap - rowStart;
            int toCopy = Math.min(copyCols, available);
            for (int x = 0; x < toCopy; x++) {
                dst.put(src.get(rowStart + x));
            }
            if (toCopy < pw) {
                int pad = pw - toCopy;
                for (int p = 0; p < pad; p++) dst.put((byte)0);
            }
        }
    }

    private String safeTrackId() {
        try { return videoTrack.id(); } catch (Exception e) { return "<unknown>"; }
    }
}