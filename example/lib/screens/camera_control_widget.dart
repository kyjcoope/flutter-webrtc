import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';

import '../audio/audio_decoder_connector.dart';
import '../config_service.dart';
import '../video/video_decoder_connector.dart';

class CameraControlWidget extends StatefulWidget {
  const CameraControlWidget({required Key key, required this.streamId})
      : super(key: key);
  final String streamId;

  @override
  State<CameraControlWidget> createState() => _CameraControlWidgetState();
}

class _CameraControlWidgetState extends State<CameraControlWidget> {
  late final WebRTCRemotePeer _remotePeer;
  late final RTCVideoRenderer _remoteRenderer;
  late final VideoDecoderConnector _videoDecoderConnector;
  late final AudioDecoderConnector _audioDecoderConnector;

  PeerConnectionState _connectionState = PeerConnectionState.initial;
  bool _receivedVideo = false;
  bool _receivedAudio = false;
  StreamSubscription? _connectionStateSubscription;
  StreamSubscription? _mediaStreamSubscription;
  bool _isMounted = false;

  String get _statusText {
    switch (_connectionState) {
      case PeerConnectionState.initial:
        return 'Idle';
      case PeerConnectionState.connecting:
        return 'Connecting...';
      case PeerConnectionState.connected:
        return "Connected${_receivedVideo ? ' (Video OK)' : ' (Waiting Video)'}";
      case PeerConnectionState.disconnected:
        return 'Disconnected';
      case PeerConnectionState.failed:
        return 'Failed';
      case PeerConnectionState.closed:
        return 'Closed';
    }
  }

  bool get _isInCall =>
      _connectionState == PeerConnectionState.connected ||
      _connectionState == PeerConnectionState.connecting;

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    _remotePeer = WebRTCRemotePeer();
    _remoteRenderer = RTCVideoRenderer();
    _videoDecoderConnector = VideoDecoderConnector();
    _audioDecoderConnector = AudioDecoderConnector();
    _initialize();
  }

  Future<void> _videoCallback(String trackId) async {
    print('Mobile Client: Video track received callback: $trackId');
    await _videoDecoderConnector.setupVideoProcessing(trackId);
  }

  Future<void> _audioCallback() async {
    print('Mobile Client: Audio track received callback');
    await _audioDecoderConnector.startAudioProcessing();
  }

  Future<void> _initialize() async {
    await _remoteRenderer.initialize();
    await _videoDecoderConnector.initialize();
    _videoDecoderConnector.onTextureId.listen((textureId) {
      print('${widget.streamId}: Received texture ID: $textureId');
    });
    await _audioDecoderConnector.initialize();
    _listenToConnectionState();
    _listenToMediaStream();
    if (_isMounted) setState(() {});
  }

  @override
  void dispose() {
    _isMounted = false;
    _connectionStateSubscription?.cancel();
    _mediaStreamSubscription?.cancel();
    _remoteRenderer.dispose();
    _remotePeer.dispose();
    _videoDecoderConnector.dispose();
    _audioDecoderConnector.dispose();
    super.dispose();
  }

  void _listenToConnectionState() {
    _connectionStateSubscription =
        _remotePeer.onConnectionStateChange.listen((state) {
      if (!_isMounted) return;
      print('${widget.streamId}: Connection state: $state');
      setState(() {
        _connectionState = state;
      });
      if (state == PeerConnectionState.closed ||
          state == PeerConnectionState.failed ||
          state == PeerConnectionState.disconnected) {
        _resetMediaState();
      }
    }, onError: (error) {
      print('${widget.streamId}: Connection state error: $error');
      if (_isMounted) {
        setState(() {
          _connectionState = PeerConnectionState.failed;
        });
        _resetMediaState();
      }
    });
  }

  void _listenToMediaStream() {
    _mediaStreamSubscription = _remotePeer.onMediaStream.listen((stream) {
      print('${widget.streamId}: Received remote stream ${stream.id}');
      if (_isMounted && _remoteRenderer.textureId != null) {
        setState(() {
          _remoteRenderer.srcObject = stream;
          _updateMediaStatus(stream);
        });
      }
    }, onError: (error) {
      print('${widget.streamId}: Media stream error: $error');
    });
  }

  void _updateMediaStatus(MediaStream? stream) {
    var video = stream?.getVideoTracks().isNotEmpty ?? false;
    var audio = stream?.getAudioTracks().isNotEmpty ?? false;
    if (_isMounted && (video != _receivedVideo || audio != _receivedAudio)) {
      setState(() {
        _receivedVideo = video;
        _receivedAudio = audio;
      });
    }
  }

  void _resetMediaState() {
    print('${widget.streamId}: Resetting media state.');
    if (_isMounted) {
      setState(() {
        _remoteRenderer.srcObject = null;
        _receivedVideo = false;
        _receivedAudio = false;
      });
    }
  }

  Future<void> _makeCall() async {
    if (_isInCall) return;
    _resetMediaState();
    setState(() {
      _connectionState = PeerConnectionState.connecting;
    });

    final config = context.read<ConfigService>();
    final signalingUrl = '${config.apiBaseUrl}/connect/${widget.streamId}';
    print('${widget.streamId}: Making call to $signalingUrl');

    try {
      await _remotePeer.connect(
          signalingUrl: signalingUrl,
          onVideoTrack: _videoCallback,
          onAudioTrack: _audioCallback);
      print(
          '${widget.streamId}: Connect call returned, waiting for state change.');
    } catch (e) {
      print('${widget.streamId}: Error making call: $e');
      if (_isMounted) {
        setState(() {
          _connectionState = PeerConnectionState.failed;
        });
        _resetMediaState();
      }
    }
  }

  Future<void> _hangUp() async {
    if (!_isInCall) return;
    print('${widget.streamId}: Hanging up...');
    if (_isMounted) {
      setState(() {
        _connectionState = PeerConnectionState.closed;
      });
    }
    _resetMediaState();
    try {
      await _remotePeer.close();
      print('${widget.streamId}: Peer close completed.');
    } catch (e) {
      print('${widget.streamId}: Error hanging up: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    var canCall = _connectionState == PeerConnectionState.initial ||
        _connectionState == PeerConnectionState.closed ||
        _connectionState == PeerConnectionState.failed ||
        _connectionState == PeerConnectionState.disconnected;
    var canHangup = _isInCall;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                    child: Text(widget.streamId,
                        style: Theme.of(context).textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 10),
                Text(_statusText,
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(width: 10),
                SizedBox(
                  width: 100,
                  child: ElevatedButton(
                    onPressed:
                        canCall ? _makeCall : (canHangup ? _hangUp : null),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canCall
                          ? Colors.green[700]
                          : (canHangup ? Colors.red[700] : Colors.grey),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    child: Text(
                        canCall ? 'Call' : (canHangup ? 'Hang Up' : '...')),
                  ),
                )
              ],
            ),
            if (_isInCall || _receivedVideo)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  margin: const EdgeInsets.only(top: 12.0),
                  decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(4)),
                  child: _remoteRenderer.textureId != null
                      ? RTCVideoView(_remoteRenderer,
                          mirror: false,
                          objectFit: RTCVideoViewObjectFit
                              .RTCVideoViewObjectFitContain)
                      : const Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
