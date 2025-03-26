import 'dart:async';
import 'dart:isolate';
import 'message_protocol.dart';
import 'video_decoder_isolate.dart';

class VideoDecoderConnector {
  Isolate? _isolate;
  SendPort? _sendPort;
  ReceivePort? _receivePort;
  Completer<void>? _initCompleter;

  final _textureIdController = StreamController<int>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  bool _isInitialized = false;
  final Set<String> _activeTrackIds = {};

  Stream<int> get onTextureId => _textureIdController.stream;
  Stream<String> get onError => _errorController.stream;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _initCompleter = Completer<void>();
      _receivePort = ReceivePort();

      print('Main: Spawning video decoder isolate...');
      _isolate = await Isolate.spawn(
        videoDecoderIsolate,
        _receivePort!.sendPort,
        debugName: 'VideoDecoderIsolate',
      ).catchError((error) {
        print('Main: Error spawning isolate: $error');
        _initCompleter?.completeError(error);
        throw error;
      });

      print('Main: Setting up isolate communication...');
      _receivePort!.listen((message) {
        if (_sendPort == null && message is SendPort) {
          _sendPort = message;
          _isInitialized = true;
          _initCompleter?.complete();
        } else if (message is IsolateMessage) {
          _handleMessage(message);
        }
      }, onError: (error) {
        print('Main: Error in receive port: $error');
        _initCompleter?.completeError(error);
      });

      return await _initCompleter!.future.timeout(
        Duration(seconds: 5),
        onTimeout: () {
          print('Main: Isolate initialization timed out');
          throw TimeoutException('Isolate initialization timed out');
        },
      );
    } catch (e) {
      print('Main: Failed to initialize isolate: $e');
      _cleanupResources();
      rethrow;
    }
  }

  void _handleMessage(IsolateMessage message) {
    switch (message.type) {
      case MessageType.textureId:
        if (!_textureIdController.isClosed) {
          final textureId = (message as TextureIdMessage).textureId;
          print('Main: Received texture ID: $textureId');
          _textureIdController.add(textureId);
        }
        break;

      case MessageType.error:
        if (!_errorController.isClosed) {
          final error = (message as ErrorMessage).error;
          print('Main: Error from isolate: $error');
          _errorController.add(error);
        }
        break;

      default:
        print('Main: Unhandled message type: ${message.type}');
        break;
    }
  }

  Future<void> setupVideoProcessing(String trackId) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_activeTrackIds.contains(trackId)) {
      return;
    }

    _activeTrackIds.add(trackId);
    _sendPort?.send(InitMessage(trackId));
  }

  Future<void> dispose() async {
    if (!_isInitialized) return;

    print('Main: Disposing video decoder connector');
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
    _activeTrackIds.clear();
    _isInitialized = false;

    _textureIdController.close();
    _errorController.close();
  }
}
