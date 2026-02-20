package com.cloudwebrtc.webrtc.record;

import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import org.webrtc.AudioTrack;
import org.webrtc.AudioTrackSink;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Captures raw PCM audio from an individual AudioTrack and pushes it
 * into the native ring buffer through JNI.
 * Mirrors the RawFrameCapturer (video) pattern for per-track audio.
 */
public class RawAudioCapturer implements AudioTrackSink {
    private static final String TAG = "RawAudioCapturer";

    static {
        try {
            System.loadLibrary("native_lib");
        } catch (UnsatisfiedLinkError e) {
            Log.e(TAG, "Failed to load native_lib: " + e.getMessage());
        }
    }

    // Native ring buffer config
    private static final int DEFAULT_CAPACITY = 64; // more frames than video since audio arrives frequently

    private static native int initNativeBuffer(String trackId, int capacity, int bufferSize);
    private static native long pushAudioFrame(String trackId,
                                              java.nio.ByteBuffer buffer,
                                              int sampleRate,
                                              int channels,
                                              long frameTimeMs);
    private static native void freeNativeBuffer(String trackId);

    private final AudioTrack audioTrack;
    private final String trackId;

    private final AtomicBoolean stopped = new AtomicBoolean(false);
    private boolean nativeInited = false;

    @SuppressWarnings("unused")
    private long frameCounter = 0;

    public RawAudioCapturer(AudioTrack track) {
        this.audioTrack = track;
        this.trackId = safeTrackId();
        this.audioTrack.addSink(this);
        Log.d(TAG, "Started raw audio capture for track: " + trackId);
    }

    public void stop() {
        if (!stopped.compareAndSet(false, true)) return;

        // Detach sink from main thread
        if (Looper.myLooper() == Looper.getMainLooper()) {
            audioTrack.removeSink(this);
        } else {
            new Handler(Looper.getMainLooper()).post(() -> {
                try {
                    audioTrack.removeSink(this);
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

        Log.d(TAG, "Stopped raw audio capture for track: " + trackId);
    }

    @Override
    public void onData(ByteBuffer audioData, int bitsPerSample, int sampleRate,
                       int numberOfChannels, int numberOfFrames) {
        if (stopped.get()) return;

        try {
            int bytesPerSample = bitsPerSample / 8;
            int dataSize = bytesPerSample * numberOfChannels * numberOfFrames;

            if (dataSize <= 0) return;

            // Initialize or reinitialize native ring buffer on first frame
            if (!nativeInited) {
                reinitNative(dataSize);
            }

            // Create a direct ByteBuffer copy for JNI
            ByteBuffer directBuffer = ByteBuffer.allocateDirect(dataSize).order(ByteOrder.nativeOrder());
            audioData.rewind();

            // Copy at most dataSize bytes
            int toCopy = Math.min(audioData.remaining(), dataSize);
            byte[] temp = new byte[toCopy];
            audioData.get(temp);
            directBuffer.put(temp);
            directBuffer.flip();

            frameCounter++;
            long seq = pushAudioFrame(trackId, directBuffer, sampleRate, numberOfChannels, 0L);
        } catch (Exception e) {
            Log.e(TAG, "Error pushing audio frame: " + e.getMessage(), e);
        }
    }

    private void reinitNative(int bufferSize) {
        // Use a generous max buffer size for audio
        int maxBufferSize = Math.max(bufferSize * 4, 19200); // 48kHz * 2ch * 2bytes * 100ms = 19200
        if (nativeInited) {
            try { freeNativeBuffer(trackId); } catch (Throwable ignore) {}
            nativeInited = false;
        }
        try {
            int ok = initNativeBuffer(trackId, DEFAULT_CAPACITY, maxBufferSize);
            if (ok != 0) {
                Log.w(TAG, "initNativeBuffer returned non-zero: " + ok);
            }
            nativeInited = true;
            Log.d(TAG, "initNativeBuffer(track=" + trackId + ", capacity=" + DEFAULT_CAPACITY +
                    ", maxBufferSize=" + maxBufferSize + ")");
        } catch (Throwable t) {
            Log.e(TAG, "initNativeBuffer failed: " + t.getMessage(), t);
        }
    }

    private String safeTrackId() {
        try {
            return audioTrack == null ? "<null>" : audioTrack.id();
        } catch (Exception e) {
            return "<unknown>";
        }
    }
}
