package com.cloudwebrtc.webrtc.record;

import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import org.webrtc.VideoFrame;
import org.webrtc.VideoSink;
import org.webrtc.VideoTrack;

import java.util.concurrent.atomic.AtomicBoolean;

public class RawFrameCapturer implements VideoSink {
    private static final String TAG = "RawFrameCapturer";

    private final VideoTrack videoTrack;
    private final AtomicBoolean stopped = new AtomicBoolean(false);
    private long frameCounter = 0;
    private long startTimeNs = -1;

    public RawFrameCapturer(VideoTrack track) {
        this.videoTrack = track;
        this.videoTrack.addSink(this);
        Log.d(TAG, "Started raw frame capture for track: " + safeTrackId());
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
        Log.d(TAG, "Stopped raw frame capture for track: " + safeTrackId());
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
                final int chromaHeight = (height + 1) / 2;

                final int yBytes = i420.getStrideY() * height;
                final int uBytes = i420.getStrideU() * chromaHeight;
                final int vBytes = i420.getStrideV() * chromaHeight;
                final int totalBytes = yBytes + uBytes + vBytes;

                if (startTimeNs < 0) startTimeNs = frame.getTimestampNs();
                frameCounter++;

                Log.d(TAG,
                        "onFrame #" + frameCounter +
                        " track=" + safeTrackId() +
                        " size=" + width + "x" + height +
                        " rotation=" + frame.getRotation() +
                        " ts(ns)=" + frame.getTimestampNs() +
                        " dataLen(I420)=" + totalBytes +
                        " [Y=" + yBytes + ",U=" + uBytes + ",V=" + vBytes + "]");
            } catch (Exception e) {
                Log.e(TAG, "Error reading I420 data: " + e.getMessage(), e);
            } finally {
                i420.release();
            }
        } catch (Throwable t) {
            Log.e(TAG, "Error processing frame: " + t.getMessage(), t);
        } finally {
            frame.release();
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