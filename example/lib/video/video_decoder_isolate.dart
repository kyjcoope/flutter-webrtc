import 'dart:isolate';
import 'message_protocol.dart';
import 'video_decoder_service.dart';

void videoDecoderIsolate(SendPort mainSendPort) {
  print('Isolate: Starting up');

  final receivePort = ReceivePort();

  mainSendPort.send(receivePort.sendPort);

  final service = VideoDecoderService(mainSendPort);

  receivePort.listen((message) async {
    if (message is! IsolateMessage) return;

    try {
      switch (message.type) {
        case MessageType.init:
          final trackId = (message as InitMessage).trackId;
          await service.initializeProcessing(trackId);
          break;

        case MessageType.dispose:
          await service.dispose();

          receivePort.close();
          break;

        default:
          print('Isolate: Unknown message type: ${message.type}');
          mainSendPort
              .send(ErrorMessage('Unknown message type: ${message.type}'));
      }
    } catch (e) {
      print('Isolate: Error processing message: $e');
      mainSendPort.send(ErrorMessage('Error processing message: $e'));
    }
  });

  print('Isolate: Setup complete');
}
