import 'dart:typed_data';
import 'dart:ffi' as ffi;
import 'native_bindings.dart';

abstract class MediaFrame {
  MediaFrame({
    required this.frameTime,
    required this.buffer,
  });
  final int frameTime;
  final Uint8List buffer;
}

class RawVideoFrame extends MediaFrame {
  RawVideoFrame({
    required this.width,
    required this.height,
    required super.frameTime,
    required this.rotation,
    required super.buffer,
  });

  factory RawVideoFrame.fromPointer(ffi.Pointer<MediaFrameNative> ptr) {
    final nativeFrame = ptr.ref;
    Uint8List bufferList =
        nativeFrame.buffer.asTypedList(nativeFrame.bufferSize);
    Uint8List buffer = Uint8List.fromList(bufferList);

    return RawVideoFrame(
      width: nativeFrame.metadata.video.width,
      height: nativeFrame.metadata.video.height,
      frameTime: nativeFrame.frameTime,
      rotation: nativeFrame.metadata.video.rotation,
      buffer: buffer,
    );
  }
  final int width;
  final int height;
  final int rotation;
}

class DecodedAudioSample extends MediaFrame {
  DecodedAudioSample({
    required this.sampleRate,
    required this.channels,
    required super.frameTime,
    required super.buffer,
  });

  factory DecodedAudioSample.fromPointer(ffi.Pointer<MediaFrameNative> ptr) {
    final nativeFrame = ptr.ref;
    Uint8List bufferList =
        nativeFrame.buffer.asTypedList(nativeFrame.bufferSize);
    Uint8List buffer = Uint8List.fromList(bufferList);

    return DecodedAudioSample(
      sampleRate: nativeFrame.metadata.audio.sampleRate,
      channels: nativeFrame.metadata.audio.channels,
      frameTime: nativeFrame.frameTime,
      buffer: buffer,
    );
  }
  final int sampleRate;
  final int channels;
}
