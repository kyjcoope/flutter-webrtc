import 'dart:async';
import 'dart:io';
import 'package:flutter_webrtc/flutter_webrtc.dart';

enum PeerConnectionState {
  initial,
  connecting,
  connected,
  disconnected,
  failed,
  closed
}

typedef VideoFrameSetupCallback = Future<void> Function(String trackId);
typedef AudioFrameSetupCallback = Future<void> Function();

class WebRTCRemotePeer {
  String? _streamLabel;
  RTCPeerConnection? connection;
  MediaStream? mediaStream;

  final StreamController<MediaStream> _mediaStreamController =
      StreamController<MediaStream>.broadcast();
  final StreamController<PeerConnectionState> _connectionStateController =
      StreamController<PeerConnectionState>.broadcast();
  final StreamController<RTCIceCandidate> _iceCandidateController =
      StreamController<RTCIceCandidate>.broadcast();

  VideoFrameSetupCallback? _onVideoTrackCallback;
  AudioFrameSetupCallback? _onAudioTrackCallback;

  bool _isInitialized = false;
  int _reconnectAttempts = 0;
  Map<String, dynamic>? _lastConfiguration;

  Stream<MediaStream> get onMediaStream => _mediaStreamController.stream;
  Stream<PeerConnectionState> get onConnectionStateChange =>
      _connectionStateController.stream;
  Stream<RTCIceCandidate> get onIceCandidate => _iceCandidateController.stream;

  Future<void> initialize({
    Map<String, dynamic>? configuration,
    String? streamLabel,
    VideoFrameSetupCallback? onVideoTrack,
    AudioFrameSetupCallback? onAudioTrack,
  }) async {
    if (_isInitialized) {
      await close();
    }

    _streamLabel = streamLabel;
    _onVideoTrackCallback = onVideoTrack;
    _onAudioTrackCallback = onAudioTrack;

    _lastConfiguration = configuration ??
        {
          'iceServers': [
            {'urls': 'stun:stun.l.google.com:19302'},
          ],
          'sdpSemantics': 'unified-plan'
        };

    connection = await createPeerConnection(_lastConfiguration!);
    _setupEventHandlers();
    _isInitialized = true;
    _connectionStateController.add(PeerConnectionState.initial);
  }

  void _setupEventHandlers() {
    connection!.onTrack = _handleTrack;

    connection!.onIceCandidate = (candidate) {
      if (!_iceCandidateController.isClosed) {
        _iceCandidateController.add(candidate);
      }
    };

    connection!.onIceConnectionState = (state) {
      switch (state) {
        case RTCIceConnectionState.RTCIceConnectionStateConnected:
          _connectionStateController.add(PeerConnectionState.connected);
          _reconnectAttempts = 0;
          break;
        case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          _connectionStateController.add(PeerConnectionState.disconnected);
          break;
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          _connectionStateController.add(PeerConnectionState.failed);
          if (_reconnectAttempts < 3) {
            _attemptReconnection();
          }
          break;
        case RTCIceConnectionState.RTCIceConnectionStateClosed:
          _connectionStateController.add(PeerConnectionState.closed);
          break;
        default:
          break;
      }
    };

    connection!.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _connectionStateController.add(PeerConnectionState.connected);
        _reconnectAttempts = 0;
      }
    };
  }

  Future<void> _attemptReconnection() async {
    _reconnectAttempts++;
    _connectionStateController.add(PeerConnectionState.connecting);

    try {
      await initialize(
        configuration: _lastConfiguration,
        streamLabel: _streamLabel,
        onVideoTrack: _onVideoTrackCallback,
        onAudioTrack: _onAudioTrackCallback,
      );
    } catch (e) {
      _connectionStateController.add(PeerConnectionState.failed);
    }
  }

  Future<RTCSessionDescription> createOffer(
      {Map<String, dynamic>? constraints}) async {
    _ensureInitialized();

    final offer = await connection!.createOffer(constraints ?? {});
    await connection!.setLocalDescription(offer);
    return offer;
  }

  Future<RTCSessionDescription> createAnswerFromOffer(
      RTCSessionDescription offer,
      {Map<String, dynamic>? constraints}) async {
    _ensureInitialized();

    await connection!.setRemoteDescription(offer);
    final answer = await connection!.createAnswer(constraints ?? {});
    await connection!.setLocalDescription(answer);
    return answer;
  }

  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    _ensureInitialized();
    await connection!.setRemoteDescription(description);
  }

  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    _ensureInitialized();
    await connection!.addCandidate(candidate);
  }

  Future<void> addIceCandidates(List<RTCIceCandidate> candidates) async {
    _ensureInitialized();
    for (var candidate in candidates) {
      await connection!.addCandidate(candidate);
    }
  }

  Future<void> _handleTrack(RTCTrackEvent event) async {
    if (mediaStream == null) {
      _streamLabel ??= 'stream_${DateTime.now().millisecondsSinceEpoch}';
      mediaStream = event.streams.isNotEmpty
          ? event.streams[0]
          : await createLocalMediaStream(_streamLabel!);

      await Helper.setSpeakerphoneOn(true);

      if (Platform.isIOS) {
        await Helper.setAppleAudioConfiguration(
          AppleAudioConfiguration(
            appleAudioCategory: AppleAudioCategory.playAndRecord,
            appleAudioCategoryOptions: {
              AppleAudioCategoryOption.defaultToSpeaker,
              AppleAudioCategoryOption.allowBluetooth,
              AppleAudioCategoryOption.mixWithOthers,
            },
            appleAudioMode: AppleAudioMode.voiceChat,
          ),
        );
      }

      if (!_mediaStreamController.isClosed) {
        _mediaStreamController.add(mediaStream!);
      }
    }

    if (!mediaStream!.getTracks().contains(event.track)) {
      await mediaStream!.addTrack(event.track);
    }

    if (event.track.kind == 'video' && event.track.id != null) {
      if (_onVideoTrackCallback != null) {
        await _onVideoTrackCallback!(event.track.id!);
      }
    } else if (event.track.kind == 'audio') {
      if (_onAudioTrackCallback != null) {
        await _onAudioTrackCallback!();
      }
    }
  }

  void _ensureInitialized() {
    if (!_isInitialized || connection == null) {
      throw StateError(
          'WebRTCRemotePeer not initialized. Call initialize() first.');
    }
  }

  Future<List<StatsReport>> getStats() async {
    _ensureInitialized();

    final stats = await connection!.getStats();
    return stats;
  }

  Future<void> close() async {
    if (mediaStream != null) {
      for (var track in mediaStream!.getTracks()) {
        await track.stop();
      }
      mediaStream = null;
    }

    if (connection != null) {
      await connection!.close();
      connection = null;
    }

    _connectionStateController.add(PeerConnectionState.closed);
    _isInitialized = false;
  }

  Future<void> dispose() async {
    await close();

    await _mediaStreamController.close();
    await _connectionStateController.close();
    await _iceCandidateController.close();
  }
}
