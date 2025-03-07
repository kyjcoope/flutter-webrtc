package org.webrtc;
import com.cloudwebrtc.webrtc.utils.AnyThreadSink;
import com.cloudwebrtc.webrtc.utils.ConstraintsMap;
import org.webrtc.VideoDecoder;
import org.webrtc.EncodedImage;

import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;

import android.util.Log;
import java.nio.ByteBuffer;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;

public class MySuperSecretDecoder implements VideoDecoder, EventChannel.StreamHandler {
  private final static String TAG = "SuperDecoder";

  public static native long getAddress(ByteBuffer buffer);

  private final EventChannel eventChannel;
  private EventChannel.EventSink eventSink;
  private final BinaryMessenger messenger;


  public MySuperSecretDecoder(BinaryMessenger messenger) {
    this.messenger = messenger;

    eventChannel = new EventChannel(this.messenger, "FlutterWebRTC/SuperDecoder");
    eventChannel.setStreamHandler(this);
  }


  @Override
  public void onListen(Object o, EventChannel.EventSink sink) {
    eventSink = new AnyThreadSink(sink);
  }

  @Override
  public void onCancel(Object o) {
    eventSink = null;
  }

  @Override
  public final VideoCodecStatus initDecode(Settings settings, Callback decodeCallback) {
    Log.d(TAG, "MY CUSTOM DECODER!!!!");
    return VideoCodecStatus.OK;
  }

  @Override
  public final VideoCodecStatus release() {
    Log.d(TAG, "MY CUSTOM DECODER RELEASES");
    return VideoCodecStatus.OK;
  }

  @Override
  public final VideoCodecStatus decode(EncodedImage frame, DecodeInfo info) {
    LocalDateTime dateTime = Instant.ofEpochMilli(frame.captureTimeMs)
                                    .atZone(ZoneId.systemDefault()) // Uses system time zone
                                    .toLocalDateTime();

    DateTimeFormatter formatter = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss.SSS");
    String formattedDate = dateTime.format(formatter);

    if(frame.frameType.equals(EncodedImage.FrameType.VideoFrameKey)) {
    long address = getAddress(frame.buffer);
    ConstraintsMap params = new ConstraintsMap();
    params.putString("event", "onFrame");
    params.putLong("address", address);
    params.putInt("rotation", frame.rotation);
    params.putLong("time", frame.captureTimeMs);
    params.putInt("frameType", frame.frameType.ordinal());
    params.putInt("bufferSize", frame.buffer.capacity());
    sendEvent(params);
    }

    // Log.d(TAG, "Decoding frame!!!!!!!!!!!!!!!!!!: " + frame.buffer.capacity() + " :: " + formattedDate + " :: " + frame.rotation + " :: " + frame.frameType + " :: " + frame.encodedWidth + "x" + frame.encodedHeight);
    return VideoCodecStatus.OK;
  }


  void sendEvent(ConstraintsMap event) {
    if (eventSink != null) {
      eventSink.success(event.toMap());
    }
  }

  @Override
  public final String getImplementationName() {
    return "MySuperSecretDecoder";
  }
}