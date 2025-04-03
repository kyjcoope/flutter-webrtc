typedef VideoFrameSetupCallback = Future<void> Function(String trackId);
typedef AudioFrameSetupCallback = Future<void> Function();

enum PeerConnectionState {
  initial,
  connecting,
  connected,
  disconnected,
  failed,
  closed
}
