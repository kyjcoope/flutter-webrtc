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
      orElse: () => MediaType.video,
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

  @ffi.Int32()
  external int bufferSize;

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
  WebRTCMediaStreamer._internal();
  static final WebRTCMediaStreamer _instance = WebRTCMediaStreamer._internal();

  final Map<String, StreamController<EncodedVideoFrame>>
      _videoStreamControllers = {};
  final StreamController<DecodedAudioSample> _audioStreamController =
      StreamController<DecodedAudioSample>.broadcast();
  final Map<String, ReceivePort> _receivePorts = {};
  static bool _dartApiInitialized = false;
  bool _audioStreamInitialized = false;

  Future<Stream<EncodedVideoFrame>> videoFramesFrom(String trackId) async {
    if (_videoStreamControllers.containsKey(trackId)) {
      return _videoStreamControllers[trackId]!.stream;
    }

    final controller = _createVideoStreamController(trackId);
    await _setupFrameNotifications(trackId, controller);
    return controller.stream;
  }

  Future<Stream<DecodedAudioSample>> audioFrames() async {
    if (!_audioStreamInitialized) {
      await _initializeAudioStream();
    }
    return _audioStreamController.stream;
  }

  StreamController<EncodedVideoFrame> _createVideoStreamController(
      String trackId) {
    final controller = StreamController<EncodedVideoFrame>.broadcast(
      onCancel: () => _checkControllerForCleanup(trackId),
    );

    _videoStreamControllers[trackId] = controller;
    return controller;
  }

  void _checkControllerForCleanup(String trackId) {
    final controller = _videoStreamControllers[trackId];
    if (controller != null && !controller.hasListener) {
      _cleanupTrackResources(trackId);
    }
  }

  Future<void> _setupFrameNotifications(
      String trackId, StreamController<EncodedVideoFrame> controller) async {
    await _ensureDartApiInitialized();

    final receivePort = ReceivePort();
    final trackIdPtr = trackId.toNativeUtf8();

    try {
      final registered =
          _registerPort(trackIdPtr, receivePort.sendPort.nativePort);
      if (!registered) {
        throw StateError("Failed to register native port for track: $trackId");
      }

      _receivePorts[trackId] = receivePort;
      receivePort.listen((_) {
        final frame = _fetchVideoFrame(trackId);
        if (frame != null && !controller.isClosed) {
          controller.add(frame);
        }
      });
    } finally {
      calloc.free(trackIdPtr);
    }
  }

  Future<void> _initializeAudioStream() async {
    await _ensureDartApiInitialized();

    final receivePort = ReceivePort();
    final audioKeyPtr = audioKey.toNativeUtf8();

    try {
      final registered =
          _registerPort(audioKeyPtr, receivePort.sendPort.nativePort);
      if (!registered) {
        throw StateError("Failed to register native port for audio");
      }

      _receivePorts[audioKey] = receivePort;
      receivePort.listen((_) {
        final frame = _fetchAudioSample();
        if (frame != null && !_audioStreamController.isClosed) {
          _audioStreamController.add(frame);
        }
      });

      _audioStreamInitialized = true;
    } finally {
      calloc.free(audioKeyPtr);
    }
  }

  Future<void> _ensureDartApiInitialized() async {
    if (_dartApiInitialized) return;

    final success = _initializeApi(ffi.NativeApi.initializeApiDLData);
    if (!success) {
      throw StateError("Failed to initialize Dart native API");
    }

    _dartApiInitialized = true;
  }

  EncodedVideoFrame? _fetchVideoFrame(String trackId) {
    final keyPtr = trackId.toNativeUtf8();
    final framePtr = _nativeBufferPop(keyPtr);
    calloc.free(keyPtr);

    if (framePtr.address == 0) return null;

    final mediaType = MediaType.fromValue(framePtr.ref.mediaType);
    if (mediaType != MediaType.video) return null;

    return EncodedVideoFrame.fromPointer(framePtr);
  }

  DecodedAudioSample? _fetchAudioSample() {
    final keyPtr = audioKey.toNativeUtf8();
    final framePtr = _nativeBufferPop(keyPtr);
    calloc.free(keyPtr);

    if (framePtr.address == 0) return null;

    final mediaType = MediaType.fromValue(framePtr.ref.mediaType);
    if (mediaType != MediaType.audio) return null;

    return DecodedAudioSample.fromPointer(framePtr);
  }

  void _cleanupTrackResources(String trackId) {
    _videoStreamControllers[trackId]?.close();
    _videoStreamControllers.remove(trackId);

    _receivePorts[trackId]?.close();
    _receivePorts.remove(trackId);
  }

  void dispose() {
    for (final controller in _videoStreamControllers.values) {
      controller.close();
    }
    _videoStreamControllers.clear();

    for (final port in _receivePorts.values) {
      port.close();
    }
    _receivePorts.clear();

    _audioStreamController.close();
    _audioStreamInitialized = false;
  }
}
