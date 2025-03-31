enum MessageType {
  init,
  audioSample,
  error,
  dispose,
}

abstract class IsolateMessage {
  const IsolateMessage();
  MessageType get type;
}

class InitMessage extends IsolateMessage {
  const InitMessage();

  @override
  MessageType get type => MessageType.init;
}

class AudioSampleMessage extends IsolateMessage {
  const AudioSampleMessage(this.samples, this.count);
  final List<int> samples;
  final int count;

  @override
  MessageType get type => MessageType.audioSample;
}

class ErrorMessage extends IsolateMessage {
  const ErrorMessage(this.error);
  final String error;

  @override
  MessageType get type => MessageType.error;
}

class DisposeMessage extends IsolateMessage {
  const DisposeMessage();

  @override
  MessageType get type => MessageType.dispose;
}
