import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRTCLocalPeerLoopback {
  RTCPeerConnection? connection;
  MediaStream? mediaStream;
  RTCRtpSender? audioSender;
  RTCRtpSender? videoSender;
  bool _isInitialized = false;

  final StreamController<MediaStream> _mediaStreamController =
      StreamController<MediaStream>.broadcast();

  Stream<MediaStream> get onMediaStream => _mediaStreamController.stream;
  MediaStream? get localStream => mediaStream;

  Future<void> initialize(
      {Map<String, dynamic>? configuration,
      Map<String, dynamic>? constraints}) async {
    if (_isInitialized) return;

    final config = configuration ??
        {
          'iceServers': [
            {'urls': 'stun:stun.l.google.com:19302'},
          ],
          'sdpSemantics': 'unified-plan',
        };

    final peerConstraints = constraints ??
        {
          'mandatory': {},
          'optional': [
            {'DtlsSrtpKeyAgreement': false},
          ],
        };

    connection = await createPeerConnection(config, peerConstraints);
    _isInitialized = true;
  }

  Future<void> startMedia(
      {bool audio = true,
      bool video = true,
      int width = 640,
      int height = 480,
      int frameRate = 30,
      String facingMode = 'user'}) async {
    if (!_isInitialized) {
      throw StateError(
          'Peer connection not initialized. Call initialize() first.');
    }

    final mediaConstraints = {
      'audio': audio,
      'video': video
          ? {
              'mandatory': {
                'minWidth': width.toString(),
                'minHeight': height.toString(),
                'minFrameRate': frameRate.toString(),
              },
              'facingMode': facingMode,
              'optional': [],
            }
          : false,
    };

    mediaStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);

    if (!_mediaStreamController.isClosed) {
      _mediaStreamController.add(mediaStream!);
    }
  }

  Future<void> addTracks() async {
    if (mediaStream == null || connection == null) {
      throw StateError('Media stream or connection not initialized');
    }

    for (var track in mediaStream!.getVideoTracks()) {
      if (videoSender == null) {
        videoSender = await connection!.addTrack(track, mediaStream!);
      } else {
        await videoSender!.replaceTrack(track);
      }
    }

    for (var track in mediaStream!.getAudioTracks()) {
      if (audioSender == null) {
        audioSender = await connection!.addTrack(track, mediaStream!);
      } else {
        await audioSender!.replaceTrack(track);
      }
    }
  }

  Future<void> setVideoCodec(String codecName) async {
    if (connection == null) {
      throw StateError('Connection not initialized');
    }

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

  Future<RTCSessionDescription> createOffer() async {
    if (connection == null) {
      throw StateError('Connection not initialized');
    }

    final offer = await connection!.createOffer();
    await connection!.setLocalDescription(offer);
    return offer;
  }

  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    if (connection == null) {
      throw StateError('Connection not initialized');
    }

    await connection!.setRemoteDescription(description);
  }

  Future<void> close() async {
    audioSender = null;
    videoSender = null;

    if (mediaStream != null) {
      for (var track in mediaStream!.getTracks()) {
        await track.stop();
      }
      await mediaStream!.dispose();
      mediaStream = null;
    }

    if (connection != null) {
      await connection!.close();
      connection = null;
    }

    await _mediaStreamController.close();
    _isInitialized = false;
  }
}
