import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class IvfWriter {
  IvfWriter({
    required this.width,
    required this.height,
    required this.framerate,
    this.timescale = 1,
  });
  final int width;
  final int height;
  final int framerate;
  final int timescale;
  final List<Uint8List> _frames = [];

  /// Feed a raw VP8 frame (as a Uint8List) into the writer.
  void feed(Uint8List frame) {
    _frames.add(frame);
  }

  /// Writes the IVF file to [fileName] using the fed frames.
  Future<void> save(String fileName) async {
    int frameCount = _frames.length;

    ByteData ivfHeader = ByteData(32);
    int offset = 0;
    // Signature "DKIF"
    ivfHeader.setUint8(offset++, 'D'.codeUnitAt(0));
    ivfHeader.setUint8(offset++, 'K'.codeUnitAt(0));
    ivfHeader.setUint8(offset++, 'I'.codeUnitAt(0));
    ivfHeader.setUint8(offset++, 'F'.codeUnitAt(0));
    // Version: 0 (2 bytes)
    ivfHeader.setUint16(offset, 0, Endian.little);
    offset += 2;
    // Header Size: 32 (2 bytes)
    ivfHeader.setUint16(offset, 32, Endian.little);
    offset += 2;
    // FourCC: "VP80"
    ivfHeader.setUint8(offset++, 'V'.codeUnitAt(0));
    ivfHeader.setUint8(offset++, 'P'.codeUnitAt(0));
    ivfHeader.setUint8(offset++, '8'.codeUnitAt(0));
    ivfHeader.setUint8(offset++, '0'.codeUnitAt(0));
    // Width (2 bytes)
    ivfHeader.setUint16(offset, width, Endian.little);
    offset += 2;
    // Height (2 bytes)
    ivfHeader.setUint16(offset, height, Endian.little);
    offset += 2;
    // Frame Rate (4 bytes)
    ivfHeader.setUint32(offset, framerate, Endian.little);
    offset += 4;
    // Time Scale (4 bytes)
    ivfHeader.setUint32(offset, timescale, Endian.little);
    offset += 4;
    // Frame Count (4 bytes)
    ivfHeader.setUint32(offset, frameCount, Endian.little);
    offset += 4;
    // Reserved (4 bytes)
    ivfHeader.setUint32(offset, 0, Endian.little);
    offset += 4;

    List<int> ivfFileBytes = [];
    ivfFileBytes.addAll(ivfHeader.buffer.asUint8List());

    for (int i = 0; i < frameCount; i++) {
      Uint8List frameData = _frames[i];
      int frameSize = frameData.length;
      ByteData frameHeader = ByteData(12);
      frameHeader.setUint32(0, frameSize, Endian.little);
      frameHeader.setUint64(4, i, Endian.little);

      ivfFileBytes.addAll(frameHeader.buffer.asUint8List());
      ivfFileBytes.addAll(frameData);
    }

    final appDocDir = await getApplicationDocumentsDirectory();
    final finalPath = path.join(appDocDir.path, fileName);
    final file = File(finalPath);

    // Write IVF file
    await file.writeAsBytes(ivfFileBytes);
    print("Created IVF file at $finalPath with $frameCount frame(s)");

    // Share the file
    final result = await Share.shareXFiles(
      [XFile(finalPath)],
      text: 'VP8 video recorded from WebRTC',
    );
    print("Share result: ${result.status}");
  }
}
