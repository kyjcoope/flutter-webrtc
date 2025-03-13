import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';

import 'encoded_webrtc_frame.dart';

base class EncodedFrame extends ffi.Struct {
  @ffi.Int32()
  external int width;

  @ffi.Int32()
  external int height;

  @ffi.Uint64()
  external int frameTime;

  @ffi.Int32()
  external int rotation;

  @ffi.Int32()
  external int frameType;

  external ffi.Pointer<ffi.Uint8> buffer;

  @ffi.Int32()
  external int bufferSize;
}

typedef NativeBufferPopNative = ffi.Pointer<EncodedFrame> Function(
    ffi.Pointer<Utf8> key);
typedef NativeBufferPopDart = ffi.Pointer<EncodedFrame> Function(
    ffi.Pointer<Utf8> key);

final ffi.DynamicLibrary nativeLib =
    ffi.DynamicLibrary.open("libnative_lib.so");

final NativeBufferPopDart nativeBufferPop = nativeLib
    .lookup<ffi.NativeFunction<NativeBufferPopNative>>("popNativeBufferFFI")
    .asFunction();

EncodedWebRTCFrame? popFrameFromTrack(String trackId) {
  final ffi.Pointer<Utf8> keyPtr = trackId.toNativeUtf8();
  final ffi.Pointer<EncodedFrame> framePtr = nativeBufferPop(keyPtr);
  calloc.free(keyPtr);
  if (framePtr.address == 0) return null;
  return EncodedWebRTCFrame.fromPointer(framePtr);
}
