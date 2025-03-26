import 'dart:async';
import 'dart:isolate';

import 'audio_decoder_isolate.dart';
import 'message_protocol.dart';

class AudioSampleInfo {
  AudioSampleInfo(this.samples, this.count);
  final List<int> samples;
  final int count;
}

class AudioDecoderConnector {
  Isolate? _isolate;
  SendPort? _sendPort;
  ReceivePort? _receivePort;
  Completer<void>? _initCompleter;

  final _audioSampleController = StreamController<AudioSampleInfo>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  bool _isInitialized = false;
  bool _isProcessing = false;

  Stream<AudioSampleInfo> get onAudioSample => _audioSampleController.stream;
  Stream<String> get onError => _errorController.stream;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _initCompleter = Completer<void>();
      _receivePort = ReceivePort();

      print('Main: Spawning audio decoder isolate...');
      _isolate = await Isolate.spawn(
        audioDecoderIsolate,
        _receivePort!.sendPort,
        debugName: 'AudioDecoderIsolate',
      ).catchError((error) {
        print('Main: Error spawning audio isolate: $error');
        _initCompleter?.completeError(error);
        throw error;
      });

      print('Main: Setting up audio isolate communication...');
      _receivePort!.listen((message) {
        if (_sendPort == null && message is SendPort) {
          _sendPort = message;
          _isInitialized = true;
          _initCompleter?.complete();
        } else if (message is IsolateMessage) {
          _handleMessage(message);
        }
      }, onError: (error) {
        print('Main: Error in audio receive port: $error');
        _initCompleter?.completeError(error);
      });

      return await _initCompleter!.future.timeout(
        Duration(seconds: 5),
        onTimeout: () {
          print('Main: Audio isolate initialization timed out');
          throw TimeoutException('Audio isolate initialization timed out');
        },
      );
    } catch (e) {
      print('Main: Failed to initialize audio isolate: $e');
      _cleanupResources();
      rethrow;
    }
  }

  void _handleMessage(IsolateMessage message) {
    switch (message.type) {
      case MessageType.audioSample:
        if (!_audioSampleController.isClosed) {
          final audioMsg = message as AudioSampleMessage;
          _audioSampleController.add(AudioSampleInfo(
            audioMsg.samples,
            audioMsg.count,
          ));
        }
        break;

      case MessageType.error:
        if (!_errorController.isClosed) {
          final error = (message as ErrorMessage).error;
          print('Main: Error from audio isolate: $error');
          _errorController.add(error);
        }
        break;

      default:
        print('Main: Unhandled audio message type: ${message.type}');
        break;
    }
  }

  Future<void> startAudioProcessing() async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_isProcessing) {
      return;
    }

    _isProcessing = true;
    _sendPort?.send(const InitMessage());
  }

  Future<void> dispose() async {
    if (!_isInitialized) return;

    print('Main: Disposing audio decoder connector');
    _sendPort?.send(const DisposeMessage());
    _cleanupResources();
  }

  void _cleanupResources() {
    _receivePort?.close();

    if (_isolate != null) {
      _isolate!.kill(priority: Isolate.immediate);
      _isolate = null;
    }

    _sendPort = null;
    _receivePort = null;
    _isInitialized = false;
    _isProcessing = false;

    _audioSampleController.close();
    _errorController.close();
  }
}
