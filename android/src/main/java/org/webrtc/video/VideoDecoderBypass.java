package org.webrtc.video;

import android.util.Log;
import java.nio.ByteBuffer;

import org.webrtc.VideoCodecInfo;
import org.webrtc.VideoDecoder;
import org.webrtc.VideoCodecStatus;
import org.webrtc.EncodedImage;
import org.webrtc.VideoDecoder.Settings;
import org.webrtc.VideoDecoder.DecodeInfo;
import org.webrtc.VideoDecoder.Callback;

public class VideoDecoderBypass implements VideoDecoder {
    private final static String TAG = "VideoDecoderBypass";
    private String trackId;
    private int codecType;
    private boolean isRingBufferInitialized = false;

    public static native int initNativeBuffer(String trackId, int capacity, int bufferSize);
    public static native long pushFrame(String trackId, ByteBuffer buffer, int width, int height,
                                        long frameTime, int rotation, int frameType, int codecType);
    public static native void freeNativeBuffer(String trackId);

    public VideoDecoderBypass(String trackId, VideoCodecInfo codecInfo) {
        this.trackId = trackId;
        this.codecType = codecStringToInt(codecInfo.name);
        Log.d(TAG, "Creating decoder for trackId: " + trackId + ", codec: " + codecInfo.name);
    }

    private int codecStringToInt(String codecName) {
        if (codecName == null) return 0; // VIDEO_CODEC_UNKNOWN
        String lowerCaseName = codecName.toLowerCase();
        if (lowerCaseName.contains("h264")) return 1;  // VIDEO_CODEC_H264  
        if (lowerCaseName.contains("h265")) return 2;  // VIDEO_CODEC_H265  
        if (lowerCaseName.contains("vp8")) return 3;   // VIDEO_CODEC_VP8
        if (lowerCaseName.contains("vp9")) return 4;   // VIDEO_CODEC_VP9 
        if (lowerCaseName.contains("av1")) return 5;   // VIDEO_CODEC_AV1
        return 0; // VIDEO_CODEC_UNKNOWN
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
            int bufferSize = buffer.capacity() + 256;
            int capacity = 30;
            Log.d(TAG, "Initialize native buffer: " + trackId + " with capacity: " + capacity + " and buffer size: " + bufferSize);
            int res = initNativeBuffer(trackId, capacity, bufferSize);
            if (res == 0) {
                Log.e(TAG, "Failed to initialize native buffer.");
                return VideoCodecStatus.ERROR;
            }
            isRingBufferInitialized = true;
            Log.d(TAG, "Native buffer initialized with slot size: " + bufferSize);
        }

        long storedAddress = pushFrame(trackId, buffer, frame.encodedWidth, frame.encodedHeight,
                frame.captureTimeMs, frame.rotation, frame.frameType.ordinal(), codecType);
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
