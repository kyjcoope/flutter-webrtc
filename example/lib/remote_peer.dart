import 'package:flutter_webrtc/flutter_webrtc.dart';

class RemotePeer {
  RTCPeerConnection? connection;

  final Map<String, dynamic> configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ],
    'sdpSemantics': 'unified-plan',
  };

  final Map<String, dynamic> constraints = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': false},
    ],
  };

  Future<void> initConnection(Function(RTCTrackEvent) onTrack) async {
    connection = await createPeerConnection(configuration, constraints);
    connection!.onTrack = onTrack;
  }

  Future<void> close() async {
    await connection?.close();
    connection = null;
  }
}
