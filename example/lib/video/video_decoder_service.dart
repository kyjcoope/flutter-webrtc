import 'dart:async';
import 'dart:isolate';
import 'package:flutter_webrtc/bindings/native_bindings.dart';
import 'message_protocol.dart';

class VideoDecoderService {
  VideoDecoderService(this._mainSendPort);
  final SendPort _mainSendPort;
  final Map<String, StreamSubscription> _subscriptions = {};

  Future<void> initializeProcessing(String trackId) async {
    if (_subscriptions.containsKey(trackId)) {
      print('Isolate: Already processing track $trackId');
      return;
    }

    print('Isolate: Setting up video processing for track $trackId');

    try {
      final videoStream = await WebRTCMediaStreamer().videoFramesFrom(trackId);

      _subscriptions[trackId] = videoStream.listen(
        (frame) {
          print(
              'Isolate: Frame received: ${frame.width}x${frame.height}, size: ${frame.buffer.length} bytes');

          if (frame.width > 0 && !_sentTexture) {
            _sentTexture = true;
            _mainSendPort.send(TextureIdMessage(1001));
          }
        },
        onError: (e) {
          print('Isolate: Error in video stream: $e');
          _mainSendPort.send(ErrorMessage('Error in video stream: $e'));
        },
      );

      print('Isolate: Video processing setup complete for track $trackId');
    } catch (e) {
      print(
          'Isolate: Failed to set up video processing for track $trackId: $e');
      _mainSendPort.send(ErrorMessage(
          'Failed to set up video processing for track $trackId: $e'));
    }
  }

  bool _sentTexture = false;

  Future<void> dispose() async {
    print('Isolate: Disposing resources');

    for (var subscription in _subscriptions.values) {
      await subscription.cancel();
    }
    _subscriptions.clear();

    WebRTCMediaStreamer().dispose();
  }
}
