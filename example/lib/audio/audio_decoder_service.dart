import 'dart:async';
import 'dart:isolate';
import 'package:flutter_webrtc/bindings/native_bindings.dart';
import 'message_protocol.dart';

class AudioDecoderService {
  AudioDecoderService(this._mainSendPort);
  final SendPort _mainSendPort;
  StreamSubscription? _audioSubscription;

  Future<void> initializeProcessing() async {
    if (_audioSubscription != null) {
      print('Isolate: Audio processing already initialized');
      return;
    }

    print('Isolate: Setting up audio processing');

    try {
      // Use constant 'audioKey' defined in native_bindings.dart
      final audioStream = await WebRTCMediaStreamer().audioFrames();

      _audioSubscription = audioStream.listen(
        (sample) {
          print('Isolate: Audio sample received: channels=${sample.channels}, '
              'sampleRate=${sample.sampleRate}, '
              'size=${sample.buffer.length} bytes');

          //final sampleData = sample.buffer;
          // _mainSendPort.send(AudioSampleMessage(
          //   truncatedSamples.toList(),
          //   sample.samplesPerChannel,
          // ));
        },
        onError: (e) {
          print('Isolate: Error in audio stream: $e');
          _mainSendPort.send(ErrorMessage('Error in audio stream: $e'));
        },
      );

      print('Isolate: Audio processing setup complete');
    } catch (e) {
      print('Isolate: Failed to set up audio processing: $e');
      _mainSendPort.send(ErrorMessage('Failed to set up audio processing: $e'));
    }
  }

  Future<void> dispose() async {
    print('Isolate: Disposing audio resources');

    await _audioSubscription?.cancel();
    _audioSubscription = null;

    WebRTCMediaStreamer().dispose();
  }
}
