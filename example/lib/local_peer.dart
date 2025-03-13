import 'package:flutter_webrtc/flutter_webrtc.dart';

class LocalPeer {
  RTCPeerConnection? connection;
  MediaStream? stream;
  RTCRtpSender? audioSender;
  RTCRtpSender? videoSender;

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

  Future<void> initConnection() async {
    connection = await createPeerConnection(configuration, constraints);
  }

  Future<void> startMedia({bool audio = true, bool video = true}) async {
    final mediaConstraints = {
      'audio': audio,
      'video': video
          ? {
              'mandatory': {
                'minWidth': '640',
                'minHeight': '480',
                'minFrameRate': '30',
              },
              'facingMode': 'user',
              'optional': [],
            }
          : false,
    };
    stream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
  }

  Future<void> setVideoCodec(String codecName) async {
    var capabilities = await getRtpSenderCapabilities('video');
    var selectedCodecs = capabilities.codecs
            ?.where((c) =>
                c.mimeType.toLowerCase().contains(codecName.toLowerCase()))
            .toList() ??
        [];

    var transceivers = await connection?.getTransceivers();
    if (transceivers != null) {
      for (var transceiver in transceivers) {
        if (transceiver.sender.track?.kind == 'video') {
          await transceiver.setCodecPreferences(selectedCodecs);
        }
      }
    }
  }

  Future<void> addTracks() async {
    if (stream == null || connection == null) return;
    for (var track in stream!.getVideoTracks()) {
      if (videoSender == null) {
        videoSender = await connection!.addTrack(track, stream!);
      } else {
        await videoSender!.replaceTrack(track);
      }
    }
    for (var track in stream!.getAudioTracks()) {
      if (audioSender == null) {
        audioSender = await connection!.addTrack(track, stream!);
      } else {
        await audioSender!.replaceTrack(track);
      }
    }
  }

  Future<void> removeTracks(
      {bool removeVideo = false, bool removeAudio = false}) async {
    if (stream == null) return;
    if (removeVideo) {
      for (var track in stream!.getVideoTracks()) {
        await track.stop();
      }
    }
    if (removeAudio) {
      for (var track in stream!.getAudioTracks()) {
        await track.stop();
      }
    }
  }

  Future<void> close() async {
    await stream?.dispose();
    await connection?.close();
    connection = null;
  }
}
