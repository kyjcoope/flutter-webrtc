package org.webrtc.video;

import android.util.Log;
import java.nio.ByteBuffer;

import org.webrtc.VideoDecoder;
import org.webrtc.VideoCodecStatus;
import org.webrtc.EncodedImage;
import org.webrtc.VideoDecoder.Settings;
import org.webrtc.VideoDecoder.DecodeInfo;
import org.webrtc.VideoDecoder.Callback;

public class VideoDecoderBypass implements VideoDecoder {
    private final static String TAG = "VideoDecoderBypass";
    private String trackId;
    private boolean isRingBufferInitialized = false;

    public static native int initNativeBuffer(String trackId, int capacity, int bufferSize);
    public static native long pushFrame(String trackId, ByteBuffer buffer, int width, int height, long frameTime, int rotation, int frameType);
    public static native void freeNativeBuffer(String trackId);

    public VideoDecoderBypass(String trackId) {
        this.trackId = trackId;
    }

    @Override
    public final VideoCodecStatus initDecode(Settings settings, Callback decodeCallback) {
        Log.d(TAG, "Initializing decoder for trackId: " + trackId);
        return VideoCodecStatus.OK;
    }

    @Override
    public final VideoCodecStatus release() {
        Log.d(TAG, "Releasing decoder for trackId: " + trackId);
        freeNativeBuffer(trackId);
        return VideoCodecStatus.OK;
    }

    @Override
    public final VideoCodecStatus decode(EncodedImage frame, DecodeInfo info) {
        ByteBuffer buffer = frame.buffer;
        if (buffer == null || !buffer.isDirect()) {
            Log.e(TAG, "Frame buffer is null or not direct.");
            return VideoCodecStatus.ERROR;
        }
        
        if (!isRingBufferInitialized) {
            int bufferSize = 1024 * 1024 * 2 + 256;
            int capacity = 10;
            Log.d(TAG, "Initialize native buffer: " + trackId + " with capacity: " + capacity + " and buffer size: " + bufferSize);
            int res = initNativeBuffer(trackId, capacity, bufferSize);
            if (res == 0) {
                Log.e(TAG, "Failed to initialize native buffer.");
                return VideoCodecStatus.ERROR;
            }
            isRingBufferInitialized = true;
            Log.d(TAG, "Native buffer initialized with slot size: " + bufferSize);
        }

        long storedAddress = pushFrame(trackId, buffer, frame.encodedWidth, frame.encodedHeight, frame.captureTimeMs, frame.rotation, frame.frameType.ordinal());
        if (storedAddress == 0) {
            Log.e(TAG, "Failed to store frame in native buffer.");
            return VideoCodecStatus.ERROR;
        }
        
        return VideoCodecStatus.OK;
    }

    @Override
    public final String getImplementationName() {
        return "VideoDecoderBypass";
    }
}
