import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:isolate';
import 'dart:async';
import 'package:ffi/ffi.dart';

import 'raw_pixel_frame.dart';

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

final class MediaFrameNative extends ffi.Struct {
  @ffi.Uint64()
  external int frameTime;

  external ffi.Pointer<ffi.Uint8> buffer;

  @ffi.Uint64()
  external int bufferSize;

  @ffi.Uint64()
  external int bufferCapacity;

  @ffi.Int32()
  external int width;
  @ffi.Int32()
  external int height;
  @ffi.Int32()
  external int rotation;
  @ffi.Int32()
  external int colorFormat;
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

typedef _PopNative = ffi.Pointer<MediaFrameNative> Function(
    ffi.Pointer<Utf8> key);
final _popNative = _nativeLib
    .lookup<ffi.NativeFunction<_PopNative>>("popNativeBufferFFI")
    .asFunction<_PopNative>();

class RawVideoFrameStream {
  factory RawVideoFrameStream() => _instance;
  RawVideoFrameStream._internal() {
    _ensureDartApiInitialized();
  }
  static final RawVideoFrameStream _instance = RawVideoFrameStream._internal();

  final Map<String, StreamController<RawPixelFrame>> _controllers = {};
  final Map<String, ReceivePort> _ports = {};
  static final Completer<bool> _initCompleter = Completer<bool>();
  static bool _dartApiInitialized = false;

  Future<Stream<RawPixelFrame>> framesFor(String trackId) async {
    await _initCompleter.future;
    if (_controllers.containsKey(trackId)) {
      return _controllers[trackId]!.stream;
    }
    final c = _createController(trackId);
    await _setupNotifications(trackId, c);
    return c.stream;
  }

  StreamController<RawPixelFrame> _createController(String trackId) {
    late StreamController<RawPixelFrame> controller;
    controller = StreamController<RawPixelFrame>.broadcast(
      onCancel: () {
        if (!controller.hasListener) {
          _cleanup(trackId);
        }
      },
    );
    _controllers[trackId] = controller;
    return controller;
  }

  Future<void> _setupNotifications(
      String trackId, StreamController controller) async {
    final port = ReceivePort();
    final keyPtr = trackId.toNativeUtf8();
    try {
      final ok = _registerPort(keyPtr, port.sendPort.nativePort);
      if (!ok) {
        port.close();
        throw StateError("registerPort failed for $trackId");
      }
      _ports[trackId] = port;
      port.listen((_) {
        final frame = _fetchFrame(trackId);
        if (frame != null && !controller.isClosed && controller.hasListener) {
          controller.add(frame);
        }
      });
    } finally {
      calloc.free(keyPtr);
    }
  }

  Future<void> _ensureDartApiInitialized() async {
    if (_dartApiInitialized) {
      await _initCompleter.future;
      return;
    }
    if (!_initCompleter.isCompleted) {
      final success = _initializeApi(ffi.NativeApi.initializeApiDLData);
      if (!success) {
        _initCompleter
            .completeError(StateError("Failed to initialize Dart Native API"));
      } else {
        _dartApiInitialized = true;
        _initCompleter.complete(true);
      }
    }
    await _initCompleter.future;
  }

  RawPixelFrame? _fetchFrame(String trackId) {
    final keyPtr = trackId.toNativeUtf8();
    try {
      final ptr = _popNative(keyPtr);
      if (ptr == ffi.nullptr) return null;
      return RawPixelFrame.fromPointer(ptr);
    } finally {
      calloc.free(keyPtr);
    }
  }

  void _cleanup(String trackId) {
    _controllers[trackId]?.close();
    _controllers.remove(trackId);
    _ports[trackId]?.close();
    _ports.remove(trackId);
  }

  void disposeTrack(String trackId) => _cleanup(trackId);

  void disposeAll() {
    for (final id in _controllers.keys.toList()) {
      _cleanup(id);
    }
    _controllers.clear();
  }
}
