enum MessageType {
  init,
  textureId,
  error,
  dispose,
}

abstract class IsolateMessage {
  const IsolateMessage();
  MessageType get type;
}

class InitMessage extends IsolateMessage {
  const InitMessage(this.trackId);
  final String trackId;

  @override
  MessageType get type => MessageType.init;
}

class TextureIdMessage extends IsolateMessage {
  const TextureIdMessage(this.textureId);
  final int textureId;

  @override
  MessageType get type => MessageType.textureId;
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
