import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'native/media_stream_track_impl.dart';

extension VideoRendererExtension on RTCVideoRenderer {
  RTCVideoValue get videoValue => value;
}

abstract class AudioControl {
  Future<void> setVolume(double volume);
}

// Add helpers to call native-only methods when available
extension MediaStreamTrackCaptureExt on MediaStreamTrack {
  Future<void> startFrameStream() async {
    final t = this;
    if (t is MediaStreamTrackNative) {
      return t.startFrameStream();
    }
    return Future.value();
  }

  Future<void> stopFrameStream() async {
    final t = this;
    if (t is MediaStreamTrackNative) {
      return t.stopFrameStream();
    }
    return Future.value();
  }
}
