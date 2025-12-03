package org.webrtc.video;

import android.util.Log;

import org.webrtc.VideoCodecInfo;
import org.webrtc.VideoDecoder;
import org.webrtc.VideoCodecStatus;
import org.webrtc.EncodedImage;

import java.nio.ByteBuffer;

public class VideoDecoderBypass implements VideoDecoder {
  private static final String TAG = "VideoDecoderBypass";

  private final String trackId;
  private final int codecType;
  private boolean isRingBufferInitialized = false;

  // Native bridge
  public static native int initNativeBuffer(String trackId, int capacity, int bufferSize);
  public static native long pushFrame(String trackId, ByteBuffer buffer, int width, int height,
                                      long frameTimeMs, int rotation, int frameType, int codecType);
  public static native void freeNativeBuffer(String trackId);

  public VideoDecoderBypass(String trackId, VideoCodecInfo codecInfo) {
    this.trackId = trackId;
    this.codecType = codecStringToInt(codecInfo != null ? codecInfo.name : null);

    Log.d(TAG, "Creating decoder for trackId=" + trackId
            + ", codec=" + (codecInfo != null ? codecInfo.name : "null")
            + ", codecTypeInt=" + codecType);
  }

  private int codecStringToInt(String codecName) {
    if (codecName == null) return 0; // VIDEO_CODEC_UNKNOWN
    String lower = codecName.toLowerCase();
    if (lower.contains("h264")) return 1;  // VIDEO_CODEC_H264
    if (lower.contains("h265") || lower.contains("hevc")) return 2;  // VIDEO_CODEC_H265
    if (lower.contains("vp8")) return 3;   // VIDEO_CODEC_VP8
    if (lower.contains("vp9")) return 4;   // VIDEO_CODEC_VP9
    if (lower.contains("av1")) return 5;   // VIDEO_CODEC_AV1
    return 0;
  }

  @Override
  public final VideoCodecStatus initDecode(Settings settings, Callback decodeCallback) {
    Log.d(TAG, "initDecode for trackId=" + trackId
            + " width=" + settings.width + " height=" + settings.height);
    // We don’t actually decode; we only forward encoded frames to native.
    return VideoCodecStatus.OK;
  }

  @Override
  public final VideoCodecStatus release() {
    Log.d(TAG, "Releasing decoder for trackId=" + trackId);
    if (trackId != null && isRingBufferInitialized) {
      try {
        freeNativeBuffer(trackId);
      } catch (Throwable t) {
        Log.e(TAG, "Error while freeing native buffer for trackId=" + trackId, t);
      }
      isRingBufferInitialized = false;
    }
    return VideoCodecStatus.OK;
  }

  @Override
  public final VideoCodecStatus decode(EncodedImage frame, DecodeInfo info) {
    if (trackId == null) {
      // This usually means CustomVideoDecoderFactory.createDecoder()
      // was called before a trackId was queued – we already log there,
      // so just drop safely.
      Log.e(TAG, "decode() called with null trackId – dropping frame.");
      return VideoCodecStatus.OK;
    }

    ByteBuffer buffer = frame.buffer;
    if (buffer == null) {
      Log.e(TAG, "decode(): frame buffer is null.");
      return VideoCodecStatus.ERROR;
    }

    if (!buffer.isDirect()) {
      // libwebrtc normally gives a direct buffer, but just in case:
      Log.w(TAG, "decode(): buffer is not direct, creating a direct copy.");
      ByteBuffer directCopy = ByteBuffer.allocateDirect(buffer.remaining());
      int oldPos = buffer.position();
      directCopy.put(buffer);
      directCopy.flip();
      buffer.position(oldPos);
      buffer = directCopy;
    }

    if (!isRingBufferInitialized) {
      int slotSizeBytes = buffer.capacity() + 256; // small safety margin
      int capacity = 30; // number of frames in the ring

      Log.d(TAG, "Initializing native ring buffer for trackId=" + trackId
              + " capacity=" + capacity + " slotSize=" + slotSizeBytes);

      int res = initNativeBuffer(trackId, capacity, slotSizeBytes);
      if (res == 0) {
        Log.e(TAG, "Failed to initialize native buffer for trackId=" + trackId);
        return VideoCodecStatus.ERROR;
      }
      isRingBufferInitialized = true;
    }

    long storedAddress = pushFrame(
            trackId,
            buffer,
            frame.encodedWidth,
            frame.encodedHeight,
            frame.captureTimeMs,
            frame.rotation,
            frame.frameType != null ? frame.frameType.ordinal() : 0,
            codecType
    );

    if (storedAddress == 0) {
      Log.e(TAG, "Failed to store frame in native buffer for trackId=" + trackId);
      return VideoCodecStatus.ERROR;
    }

    // We don’t call decodeCallback; we just bypass to native.
    return VideoCodecStatus.OK;
  }

  @Override
  public final String getImplementationName() {
    return "VideoDecoderBypass";
  }
}
