import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc_example/loopback/rtc_local_peer_loopback.dart';

import '../audio/audio_decoder_connector.dart';
import '../video/video_decoder_connector.dart';
import 'rtc_remote_peer_loopback.dart';

class SimpleLoopback extends StatefulWidget {
  @override
  _SimpleLoopbackState createState() => _SimpleLoopbackState();
}

class _SimpleLoopbackState extends State<SimpleLoopback> {
  final WebRTCLocalPeerLoopback _localPeer = WebRTCLocalPeerLoopback();
  final WebRTCRemotePeerLoopback _remotePeer = WebRTCRemotePeerLoopback();
  final VideoDecoderConnector _videoDecoder = VideoDecoderConnector();
  final AudioDecoderConnector _audioDecoder = AudioDecoderConnector();
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();

  bool _inCall = false;
  StreamSubscription? _textureIdSubscription;
  StreamSubscription? _audioSampleSubscription;
  StreamSubscription? _videoErrorSubscription;
  StreamSubscription? _audioErrorSubscription;
  int? _textureId;
  AudioSampleInfo? _lastAudioSample;

  @override
  void initState() {
    super.initState();
    _setupDecoders();
  }

  Future<void> _setupDecoders() async {
    // Initialize video decoder
    await _videoDecoder.initialize();

    _textureIdSubscription = _videoDecoder.onTextureId.listen((textureId) {
      setState(() {
        _textureId = textureId;
      });
      _addLog('Video: Received texture ID: $textureId');
    });

    _videoErrorSubscription = _videoDecoder.onError.listen((error) {
      _addLog('Video ERROR: $error');
    });

    // Initialize audio decoder
    await _audioDecoder.initialize();

    _audioSampleSubscription = _audioDecoder.onAudioSample.listen((sample) {
      setState(() {
        _lastAudioSample = sample;
      });
      _addLog(
          'Audio: Received sample with ${sample.count} samples, first few bytes: ${sample.samples.take(5)}');
    });

    _audioErrorSubscription = _audioDecoder.onError.listen((error) {
      _addLog('Audio ERROR: $error');
    });
  }

  @override
  void dispose() {
    _textureIdSubscription?.cancel();
    _audioSampleSubscription?.cancel();
    _videoErrorSubscription?.cancel();
    _audioErrorSubscription?.cancel();

    _videoDecoder.dispose();
    _audioDecoder.dispose();
    _hangUp();
    _scrollController.dispose();
    super.dispose();
  }

  void _addLog(String message) {
    setState(() {
      final timestamp = DateTime.now().toString().split('.').first;
      _logs.add('[$timestamp] $message');
      if (_logs.length > 100) {
        _logs.removeAt(0);
      }
    });

    Future.delayed(Duration(milliseconds: 50), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _makeCall() async {
    _addLog('Initializing connection...');

    // Set up video processing callback
    final videoCallback = (String trackId) async {
      _addLog('Setting up video decoding for track: $trackId');
      await _videoDecoder.setupVideoProcessing(trackId);
    };

    // Set up audio processing callback
    final audioCallback = () async {
      _addLog('Setting up audio decoding');
      await _audioDecoder.startAudioProcessing();
    };

    await _localPeer.initialize();
    await _remotePeer.initialize(
      onVideoTrack: videoCallback,
      onAudioTrack: audioCallback,
    );

    _localPeer.connection?.onIceCandidate = (candidate) {
      _remotePeer.connection?.addCandidate(candidate);
    };
    _remotePeer.connection?.onIceCandidate = (candidate) {
      _localPeer.connection?.addCandidate(candidate);
    };

    _addLog('Starting media...');
    await _localPeer.startMedia(audio: true, video: true);
    await _localPeer.addTracks();
    await _localPeer.setVideoCodec('h264');

    _addLog('Creating offer...');
    final offer = await _localPeer.createOffer();

    _addLog('Processing offer and creating answer...');
    final answer = await _remotePeer.createAnswerFromOffer(offer);

    _addLog('Setting remote description...');
    await _localPeer.setRemoteDescription(answer);

    setState(() {
      _inCall = true;
    });
    _addLog('Call established');
  }

  Future<void> _hangUp() async {
    _addLog('Hanging up...');

    await _localPeer.close();
    await _remotePeer.close();

    setState(() {
      _inCall = false;
      _textureId = null;
      _lastAudioSample = null;
    });
    _addLog('Call ended');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Media Decoder Demo'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  'Media Processing Test',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (_textureId != null) Text('Video Texture ID: $_textureId'),
                if (_lastAudioSample != null)
                  Text('Last Audio Sample: ${_lastAudioSample!.count} samples'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _inCall ? _hangUp : _makeCall,
                  child: Text(_inCall ? 'Hang Up' : 'Make Call'),
                ),
                SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _logs.clear();
                    });
                  },
                  child: Text('Clear Logs'),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: EdgeInsets.all(8.0),
              padding: EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  return Text(
                    _logs[index],
                    style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
