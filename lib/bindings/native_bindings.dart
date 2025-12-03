import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:isolate';
import 'dart:async';
import 'package:ffi/ffi.dart';

import 'media_frame.dart';

const String audioKey = "webrtc_audio_output";

final ffi.DynamicLibrary _nativeLib = _loadLibrary();

ffi.DynamicLibrary _loadLibrary() {
  if (Platform.isAndroid) {
    return ffi.DynamicLibrary.open("libnative_lib.so");
  } else if (Platform.isIOS) {
    return ffi.DynamicLibrary.process();
  } else {
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }
}

enum MediaType {
  video(0),
  audio(1);

  const MediaType(this.value);

  factory MediaType.fromValue(int value) {
    return MediaType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => throw ArgumentError('Invalid MediaType value: $value'),
    );
  }

  final int value;
}

base class VideoMetadata extends ffi.Struct {
  @ffi.Int32()
  external int width;

  @ffi.Int32()
  external int height;

  @ffi.Int32()
  external int rotation;

  @ffi.Int32()
  external int frameType;

  @ffi.Int32()
  external int codecType;
}

base class AudioMetadata extends ffi.Struct {
  @ffi.Int32()
  external int sampleRate;

  @ffi.Int32()
  external int channels;
}

base class MediaMetadata extends ffi.Union {
  external VideoMetadata video;
  external AudioMetadata audio;
}

base class MediaFrameNative extends ffi.Struct {
  @ffi.Int32()
  external int mediaType;

  @ffi.Uint64()
  external int frameTime;

  external ffi.Pointer<ffi.Uint8> buffer;

  @ffi.Uint64()
  external int bufferSize;

  @ffi.Uint64()
  external int bufferCapacity;

  external MediaMetadata metadata;
}

typedef InitializeDartApiDLFunc = ffi.Bool Function(ffi.Pointer<ffi.Void>);
typedef InitializeDartApiDL = bool Function(ffi.Pointer<ffi.Void>);
final _initializeApi = _nativeLib
    .lookup<ffi.NativeFunction<InitializeDartApiDLFunc>>('initializeDartApiDL')
    .asFunction<InitializeDartApiDL>();

typedef RegisterDartPortFunc = ffi.Bool Function(ffi.Pointer<Utf8>, ffi.Int64);
typedef RegisterDartPort = bool Function(ffi.Pointer<Utf8>, int);
final _registerPort = _nativeLib
    .lookup<ffi.NativeFunction<RegisterDartPortFunc>>('registerDartPort')
    .asFunction<RegisterDartPort>();

typedef _NativeBufferPopNative = ffi.Pointer<MediaFrameNative> Function(
    ffi.Pointer<Utf8> key);
typedef NativeBufferPopDart = ffi.Pointer<MediaFrameNative> Function(
    ffi.Pointer<Utf8> key);
final NativeBufferPopDart _nativeBufferPop = _nativeLib
    .lookup<ffi.NativeFunction<_NativeBufferPopNative>>("popNativeBufferFFI")
    .asFunction();

class WebRTCMediaStreamer {
  factory WebRTCMediaStreamer() => _instance;
  WebRTCMediaStreamer._internal() {
    _ensureDartApiInitialized();
  }
  static final WebRTCMediaStreamer _instance = WebRTCMediaStreamer._internal();

  final Map<String, StreamController<EncodedVideoFrame>>
      _videoStreamControllers = {};
  final StreamController<DecodedAudioSample> _audioStreamController =
      StreamController<DecodedAudioSample>.broadcast();
  final Map<String, ReceivePort> _receivePorts = {};
  static final Completer<bool> _dartApiInitializationCompleter =
      Completer<bool>();
  static bool _dartApiInitialized = false;
  bool _audioStreamInitialized = false;

  Future<Stream<EncodedVideoFrame>> videoFramesFrom(String trackId) async {
    await _dartApiInitializationCompleter.future;
    if (_videoStreamControllers.containsKey(trackId)) {
      return _videoStreamControllers[trackId]!.stream;
    }

    final controller = _createVideoStreamController(trackId);
    await _setupFrameNotifications(trackId, controller);
    return controller.stream;
  }

  Future<Stream<DecodedAudioSample>> audioFrames() async {
    await _dartApiInitializationCompleter.future;
    if (!_audioStreamInitialized) {
      await _initializeAudioStream();
    }
    return _audioStreamController.stream;
  }

  StreamController<EncodedVideoFrame> _createVideoStreamController(
      String trackId) {
    late StreamController<EncodedVideoFrame> controller;
    controller = StreamController<EncodedVideoFrame>.broadcast(
      onListen: () {},
      onCancel: () {
        if (!controller.hasListener) {
          _cleanupTrackResources(trackId);
        }
      },
    );

    _videoStreamControllers[trackId] = controller;
    return controller;
  }

  Future<void> _setupFrameNotifications(
      String trackId, StreamController controller) async {
    final receivePort = ReceivePort();
    final trackIdPtr = trackId.toNativeUtf8();

    try {
      final registered =
          _registerPort(trackIdPtr, receivePort.sendPort.nativePort);
      if (!registered) {
        receivePort.close();
        throw StateError("Failed to register native port for track: $trackId");
      }

      _receivePorts[trackId] = receivePort;
      receivePort.listen((message) {
        final currentController = _videoStreamControllers[trackId];
        if (currentController != null && currentController.hasListener) {
          final frame = _fetchVideoFrame(trackId);
          if (frame != null && !currentController.isClosed) {
            currentController.add(frame);
          }
        }
      });
    } catch (e) {
      receivePort.close();
      calloc.free(trackIdPtr);
      rethrow;
    } finally {
      calloc.free(trackIdPtr);
    }
  }

  Future<void> _initializeAudioStream() async {
    if (_audioStreamInitialized) return;

    final receivePort = ReceivePort();
    final audioKeyPtr = audioKey.toNativeUtf8();

    try {
      final registered =
          _registerPort(audioKeyPtr, receivePort.sendPort.nativePort);
      if (!registered) {
        receivePort.close();
        throw StateError("Failed to register native port for audio");
      }

      _receivePorts[audioKey] = receivePort;
      receivePort.listen((message) {
        if (_audioStreamController.hasListener) {
          final frame = _fetchAudioSample();
          if (frame != null && !_audioStreamController.isClosed) {
            _audioStreamController.add(frame);
          }
        }
      });

      _audioStreamInitialized = true;
    } catch (e) {
      receivePort.close();
      calloc.free(audioKeyPtr);
      rethrow;
    } finally {
      calloc.free(audioKeyPtr);
    }
  }

  Future<void> _ensureDartApiInitialized() async {
    if (_dartApiInitialized) await _dartApiInitializationCompleter.future;

    if (!_dartApiInitializationCompleter.isCompleted) {
      try {
        final success = _initializeApi(ffi.NativeApi.initializeApiDLData);
        if (!success) {
          _dartApiInitializationCompleter.completeError(
              StateError("Failed to initialize Dart native API"));
        } else {
          _dartApiInitialized = true;
          _dartApiInitializationCompleter.complete(true);
        }
      } catch (e) {
        _dartApiInitializationCompleter.completeError(e);
      }
    }
    await _dartApiInitializationCompleter.future;
  }

  EncodedVideoFrame? _fetchVideoFrame(String trackId) {
    final keyPtr = trackId.toNativeUtf8();
    ffi.Pointer<MediaFrameNative> framePtr = ffi.nullptr;
    try {
      framePtr = _nativeBufferPop(keyPtr);
      if (framePtr == ffi.nullptr || framePtr.address == 0) {
        return null;
      }

      final nativeFrame = framePtr.ref;
      final mediaType = MediaType.fromValue(nativeFrame.mediaType);

      if (mediaType != MediaType.video) {
        return null;
      }
      return EncodedVideoFrame.fromPointer(framePtr);
    } catch (e) {
      return null;
    } finally {
      calloc.free(keyPtr);
    }
  }

  DecodedAudioSample? _fetchAudioSample() {
    final keyPtr = audioKey.toNativeUtf8();
    ffi.Pointer<MediaFrameNative> framePtr = ffi.nullptr;
    try {
      framePtr = _nativeBufferPop(keyPtr);
      if (framePtr == ffi.nullptr || framePtr.address == 0) {
        return null;
      }

      final nativeFrame = framePtr.ref;
      final mediaType = MediaType.fromValue(nativeFrame.mediaType);

      if (mediaType != MediaType.audio) {
        return null;
      }
      return DecodedAudioSample.fromPointer(framePtr);
    } catch (e) {
      return null;
    } finally {
      calloc.free(keyPtr);
    }
  }

  void _cleanupTrackResources(String trackId) {
    _videoStreamControllers[trackId]?.close();
    _videoStreamControllers.remove(trackId);

    _receivePorts[trackId]?.close();
    _receivePorts.remove(trackId);
  }

  void dispose() {
    for (final trackId in _videoStreamControllers.keys.toList()) {
      _cleanupTrackResources(trackId);
    }
    _videoStreamControllers.clear();
    disposeAudioStream();
  }

  void disposeVideoStream(String trackId) {
    if (!_videoStreamControllers.containsKey(trackId)) return;
    _cleanupTrackResources(trackId);
  }

  void disposeAudioStream() {
    if (!_audioStreamInitialized) return;
    _audioStreamController.close();
    _audioStreamInitialized = false;
    _receivePorts[audioKey]?.close();
    _receivePorts.remove(audioKey);
  }
}
