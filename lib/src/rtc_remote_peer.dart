import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_webrtc/bindings/native_bindings.dart';
import 'package:flutter_webrtc/bindings/media_frame.dart';

class WebRTCRemotePeer {
  RTCPeerConnection? connection;
  MediaStream? mediaStream;
  final Map<String, StreamSubscription> _frameSubscriptions = {};
  final StreamController<MediaStream> _mediaStreamController =
      StreamController<MediaStream>.broadcast();
  final StreamController<EncodedVideoFrame> _videoFrameController =
      StreamController<EncodedVideoFrame>.broadcast();
  final StreamController<DecodedAudioSample> _audioFrameController =
      StreamController<DecodedAudioSample>.broadcast();

  Stream<MediaStream> get onMediaStream => _mediaStreamController.stream;
  Stream<EncodedVideoFrame> get onVideoFrame => _videoFrameController.stream;
  Stream<DecodedAudioSample> get onAudioFrame => _audioFrameController.stream;

  Future<void> initialize({Map<String, dynamic>? configuration}) async {
    final config = configuration ??
        {
          'iceServers': [
            {'urls': 'stun:stun.l.google.com:19302'},
          ],
          'sdpSemantics': 'unified-plan'
        };

    connection = await createPeerConnection(config);
    connection!.onTrack = _handleTrack;
  }

  Future<RTCSessionDescription> createAnswerFromOffer(
      RTCSessionDescription offer) async {
    await connection!.setRemoteDescription(offer);
    final answer = await connection!.createAnswer();
    await connection!.setLocalDescription(answer);
    return answer;
  }

  Future<void> _handleTrack(RTCTrackEvent event) async {
    if (mediaStream == null) {
      mediaStream = event.streams.isNotEmpty
          ? event.streams[0]
          : await createLocalMediaStream('remote_stream');

      await Helper.setSpeakerphoneOn(true);
      _mediaStreamController.add(mediaStream!);
    }

    if (!mediaStream!.getTracks().contains(event.track)) {
      await mediaStream!.addTrack(event.track);
    }

    if (event.track.kind == 'video' && event.track.id != null) {
      _setupVideoFrameProcessing(event.track.id!);
    } else if (event.track.kind == 'audio') {
      _setupAudioFrameProcessing();
    }
  }

  void _setupVideoFrameProcessing(String trackId) async {
    final videoStream = await WebRTCMediaStreamer().videoFramesFrom(trackId);

    _frameSubscriptions[trackId] = videoStream.listen((frame) {
      if (!_videoFrameController.isClosed) {
        _videoFrameController.add(frame);
      }
    });
  }

  void _setupAudioFrameProcessing() async {
    if (_frameSubscriptions.containsKey(audioKey)) return;

    final audioStream = await WebRTCMediaStreamer().audioFrames();

    _frameSubscriptions[audioKey] = audioStream.listen((sample) {
      if (!_audioFrameController.isClosed) {
        _audioFrameController.add(sample);
      }
    });
  }

  Future<void> close() async {
    for (var subscription in _frameSubscriptions.values) {
      await subscription.cancel();
    }
    _frameSubscriptions.clear();

    WebRTCMediaStreamer().dispose();

    if (connection != null) {
      await connection!.close();
      connection = null;
    }

    mediaStream = null;
    await _mediaStreamController.close();
    await _videoFrameController.close();
    await _audioFrameController.close();
  }
}
