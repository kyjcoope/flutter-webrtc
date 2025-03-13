import 'dart:typed_data';
import 'dart:ffi' as ffi;
import 'native_bindings.dart';

class EncodedWebRTCFrame {
  EncodedWebRTCFrame({
    required this.width,
    required this.height,
    required this.frameTime,
    required this.rotation,
    required this.frameType,
    required this.buffer,
    required this.bufferSize,
  });

  factory EncodedWebRTCFrame.fromPointer(ffi.Pointer<EncodedFrame> ptr) {
    final nativeFrame = ptr.ref;
    Uint8List bufferList =
        nativeFrame.buffer.asTypedList(nativeFrame.bufferSize);
    return EncodedWebRTCFrame(
      width: nativeFrame.width,
      height: nativeFrame.height,
      frameTime: nativeFrame.frameTime,
      rotation: nativeFrame.rotation,
      frameType: nativeFrame.frameType,
      buffer: bufferList,
      bufferSize: nativeFrame.bufferSize,
    );
  }

  final int width;
  final int height;
  final int frameTime;
  final int rotation;
  final int frameType;
  final Uint8List buffer;
  final int bufferSize;

  Uint8List getBufferAsUint8List() => buffer;
}
