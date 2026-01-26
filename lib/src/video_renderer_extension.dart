import 'package:webrtc_interface/webrtc_interface.dart';
import 'native/media_stream_track_impl.dart';

abstract class AudioControl {
  set muted(bool mute);
  bool get muted;
  Future<bool> audioOutput(String deviceId);
  Future<void> setVolume(double volume);
}

extension MediaStreamTrackCaptureExt on MediaStreamTrack {
  Future<void> startFrameCapture() async {
    final t = this;
    if (t is MediaStreamTrackNative) {
      return t.startFrameCapture();
    }
    return Future.value();
  }

  Future<void> stopFrameCapture() async {
    final t = this;
    if (t is MediaStreamTrackNative) {
      return t.stopFrameCapture();
    }
    return Future.value();
  }
}
