import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;

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
  RTCPeerConnection? _connection;
  MediaStream? _mediaStream;
  bool _isConnecting = false;
  bool _isConnected = false;

  VideoFrameSetupCallback? _onVideoTrackCallback;
  AudioFrameSetupCallback? _onAudioTrackCallback;

  final StreamController<MediaStream> _mediaStreamController =
      StreamController<MediaStream>.broadcast();
  final StreamController<PeerConnectionState> _connectionStateController =
      StreamController<PeerConnectionState>.broadcast();
  final StreamController<RTCIceCandidate> _iceCandidateController =
      StreamController<RTCIceCandidate>.broadcast();

  Stream<MediaStream> get onMediaStream => _mediaStreamController.stream;
  Stream<PeerConnectionState> get onConnectionStateChange =>
      _connectionStateController.stream;
  Stream<RTCIceCandidate> get onIceCandidate => _iceCandidateController.stream;

  Future<void> connect({
    required String signalingUrl,
    required VideoFrameSetupCallback onVideoTrack,
    required AudioFrameSetupCallback onAudioTrack,
    Map<String, dynamic>? configuration,
    Map<String, dynamic>? offerConstraints,
  }) async {
    if (_isConnecting || _isConnected) {
      print('WebRTCRemotePeer: Already connecting or connected.');
      return;
    }
    _isConnecting = true;
    _isConnected = false;
    _connectionStateController.add(PeerConnectionState.connecting);

    _onVideoTrackCallback = onVideoTrack;
    _onAudioTrackCallback = onAudioTrack;

    final peerConfig = configuration ??
        {
          'iceServers': [
            {'urls': 'stun:stun.l.google.com:19302'}
          ],
          'sdpSemantics': 'unified-plan'
        };

    final constraints = offerConstraints ??
        {
          'mandatory': {
            'OfferToReceiveVideo': true,
            'OfferToReceiveAudio': true,
          },
        };

    try {
      _connection = await createPeerConnection(peerConfig);
      _setupEventHandlers();

      print('WebRTCRemotePeer: Creating offer...');
      final offer = await _connection!.createOffer(constraints);
      await _connection!.setLocalDescription(offer);
      print('WebRTCRemotePeer: Offer created and local description set.');

      print('WebRTCRemotePeer: Sending offer to $signalingUrl');
      final response = await http
          .post(
            Uri.parse(signalingUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'sdp': offer.sdp, 'type': offer.type}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final answerJson = jsonDecode(response.body);
        final answer = RTCSessionDescription(
          answerJson['sdp'],
          answerJson['type'],
        );
        print('WebRTCRemotePeer: Received answer from server.');

        await _connection!.setRemoteDescription(answer);
        print(
            'WebRTCRemotePeer: Remote description set. Connection establishing...');
      } else {
        throw Exception(
            'Signaling server error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('WebRTCRemotePeer: Connection failed: $e');
      _connectionStateController.add(PeerConnectionState.failed);
      await close();
      _isConnecting = false;
      _isConnected = false;
    }
  }

  void _setupEventHandlers() {
    _connection!.onTrack = _handleTrack;
    _connection!.onIceCandidate = (candidate) {
      if (!_iceCandidateController.isClosed) {
        _iceCandidateController.add(candidate);
      }
    };
    _connection!.onIceConnectionState = (state) {
      print('WebRTCRemotePeer: ICE Connection State: $state');
      switch (state) {
        case RTCIceConnectionState.RTCIceConnectionStateConnected:
        case RTCIceConnectionState.RTCIceConnectionStateCompleted:
          if (!_isConnected && !_isConnecting) return;
          if (!_connectionStateController.isClosed && _isConnected == false) {
            _connectionStateController.add(PeerConnectionState.connected);
            _isConnected = true;
            _isConnecting = false;
          }
          break;
        case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          if (!_isConnected && !_isConnecting) return;
          if (!_connectionStateController.isClosed) {
            _connectionStateController.add(PeerConnectionState.disconnected);
            _isConnected = false;
            _isConnecting = false;
          }
          break;
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          if (!_isConnected && !_isConnecting) return;
          if (!_connectionStateController.isClosed) {
            _connectionStateController.add(PeerConnectionState.failed);
            _isConnected = false;
            _isConnecting = false;
            close();
          }
          break;
        case RTCIceConnectionState.RTCIceConnectionStateClosed:
          if (!_isConnected &&
              !_isConnecting &&
              _connectionStateController.isClosed) {
            return;
          }
          if (!_connectionStateController.isClosed) {
            _connectionStateController.add(PeerConnectionState.closed);
            _isConnected = false;
            _isConnecting = false;
          }
          break;
        default:
          break;
      }
    };
    _connection!.onConnectionState = (state) {
      print('WebRTCRemotePeer: Peer Connection State: $state');
    };
  }

  Future<void> _handleTrack(RTCTrackEvent event) async {
    print(
        'WebRTCRemotePeer: Track received - Kind: ${event.track.kind}, ID: ${event.track.id}');
    if (event.streams.isEmpty) {
      print('WebRTCRemotePeer: Error - Track event received with no streams.');
      return;
    }
    if (_mediaStream == null) {
      _mediaStream = event.streams[0];
      print('WebRTCRemotePeer: Assigned MediaStream: ${_mediaStream!.id}');
      await Helper.setSpeakerphoneOn(true);
      if (Platform.isIOS) {
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
      }
      if (!_mediaStreamController.isClosed) {
        _mediaStreamController.add(_mediaStream!);
      }
    }
    if (event.track.kind == 'video' && event.track.id != null) {
      await _onVideoTrackCallback?.call(event.track.id!);
    } else if (event.track.kind == 'audio') {
      await _onAudioTrackCallback?.call();
    }
  }

  Future<void> close() async {
    print('WebRTCRemotePeer: Closing connection...');
    if (_mediaStream != null) {
      _mediaStream = null;
    }
    if (_connection != null) {
      await _connection!.close();
      _connection = null;
    }
    if (_isConnected || _isConnecting) {
      if (!_connectionStateController.isClosed) {
        _connectionStateController.add(PeerConnectionState.closed);
      }
    }
    _isConnected = false;
    _isConnecting = false;
    print('WebRTCRemotePeer: Connection closed.');
  }

  Future<void> dispose() async {
    print('WebRTCRemotePeer: Disposing...');
    await close();
    await _mediaStreamController.close();
    await _connectionStateController.close();
    await _iceCandidateController.close();
    print('WebRTCRemotePeer: Disposed.');
  }
}
