import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';

import 'media_frame.dart';

const String audioKey = "webrtc_audio_output";

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

typedef NativeBufferPopNative = ffi.Pointer<MediaFrameNative> Function(
    ffi.Pointer<Utf8> key);
typedef NativeBufferPopDart = ffi.Pointer<MediaFrameNative> Function(
    ffi.Pointer<Utf8> key);

final ffi.DynamicLibrary nativeLib = _loadLibrary();

ffi.DynamicLibrary _loadLibrary() {
  if (Platform.isAndroid) {
    return ffi.DynamicLibrary.open("libnative_lib.so");
  } else if (Platform.isIOS) {
    return ffi.DynamicLibrary.process();
  } else {
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }
}

final NativeBufferPopDart nativeBufferPop = nativeLib
    .lookup<ffi.NativeFunction<NativeBufferPopNative>>("popNativeBufferFFI")
    .asFunction();

EncodedVideoFrame? popVideoFrame(String trackId) {
  final ffi.Pointer<Utf8> keyPtr = trackId.toNativeUtf8();
  final ffi.Pointer<MediaFrameNative> framePtr = nativeBufferPop(keyPtr);
  calloc.free(keyPtr);

  if (framePtr.address == 0) return null;

  final mediaType = MediaType.fromValue(framePtr.ref.mediaType);
  if (mediaType != MediaType.video) return null;

  return EncodedVideoFrame.fromPointer(framePtr);
}

EncodedAudioFrame? popAudioFrame() {
  final ffi.Pointer<Utf8> keyPtr = audioKey.toNativeUtf8();
  final ffi.Pointer<MediaFrameNative> framePtr = nativeBufferPop(keyPtr);
  calloc.free(keyPtr);

  if (framePtr.address == 0) return null;

  final mediaType = MediaType.fromValue(framePtr.ref.mediaType);
  if (mediaType != MediaType.audio) return null;

  return EncodedAudioFrame.fromPointer(framePtr);
}

EncodedVideoFrame? popFrameFromTrack(String trackId) {
  return popVideoFrame(trackId);
}
