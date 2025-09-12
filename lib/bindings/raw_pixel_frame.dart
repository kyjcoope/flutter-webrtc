import 'dart:typed_data';
import 'dart:ffi' as ffi;
import 'native_bindings.dart';

class RawPixelFrame {
  RawPixelFrame({
    required this.width,
    required this.height,
    required this.rotation,
    required this.colorFormat,
    required this.frameTime,
    required this.buffer,
  });

  factory RawPixelFrame.fromPointer(ffi.Pointer<MediaFrameNative> ptr) {
    final native = ptr.ref;
    final data = native.buffer.asTypedList(native.bufferSize);
    return RawPixelFrame(
      width: native.width,
      height: native.height,
      rotation: native.rotation,
      colorFormat: native.colorFormat,
      frameTime: native.frameTime,
      buffer: Uint8List.fromList(data),
    );
  }

  final int width;
  final int height;
  final int rotation;
  final int colorFormat;
  final int frameTime;
  final Uint8List buffer;
}
