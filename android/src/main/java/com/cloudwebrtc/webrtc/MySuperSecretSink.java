package com.cloudwebrtc.webrtc;
import android.util.Log;

import org.webrtc.VideoSink;
import org.webrtc.VideoFrame;

public class MySuperSecretSink implements VideoSink {
  private final static String TAG = FlutterWebRTCPlugin.TAG;

    @Override
    public void onFrame(VideoFrame videoFrame) {
        Log.d(TAG, "MY CUSTOM SINK!!!!: " + videoFrame.getRotatedWidth() + "x" + videoFrame.getRotatedHeight() + " :: " + videoFrame.getBuffer().getWidth() + "x" + videoFrame.getBuffer().getHeight());
    }
}