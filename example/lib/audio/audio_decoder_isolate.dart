import 'dart:isolate';

import 'audio_decoder_service.dart';
import 'message_protocol.dart';

void audioDecoderIsolate(SendPort mainSendPort) {
  print('Isolate: Starting audio decoder isolate');

  final receivePort = ReceivePort();

  mainSendPort.send(receivePort.sendPort);

  final service = AudioDecoderService(mainSendPort);

  receivePort.listen((message) async {
    if (message is! IsolateMessage) return;

    try {
      switch (message.type) {
        case MessageType.init:
          await service.initializeProcessing();
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

  print('Isolate: Audio decoder setup complete');
}
