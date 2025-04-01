import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_webrtc_example/audio/audio_decoder_connector.dart';
import 'package:flutter_webrtc_example/video/video_decoder_connector.dart';

class RemotePeerExample extends StatefulWidget {
  const RemotePeerExample({super.key});
  @override
  State<StatefulWidget> createState() => _RemotePeerExampleState();
}

class _RemotePeerExampleState extends State<RemotePeerExample> {
  bool _inCall = false;
  final WebRTCRemotePeer _remotePeer = WebRTCRemotePeer();
  final VideoDecoderConnector _videoDecoderConnector = VideoDecoderConnector();
  final AudioDecoderConnector _audioDecoderConnector = AudioDecoderConnector();
  static const String _signalingUrl = 'https://192.168.5.238:8080/offer';
  late Future<void> _future;

  @override
  void initState() {
    super.initState();
    _future = _init();

    _remotePeer.onConnectionStateChange.listen((state) {
      print('Received connection state: $state');
      if (mounted) {
        setState(() {
          _inCall = (state == PeerConnectionState.connected);
          if (state == PeerConnectionState.closed ||
              state == PeerConnectionState.failed) {
            print('Connection closed or failed');
          }
        });
      }
    });
  }

  Future<void> _init() async {
    await _videoDecoderConnector.initialize();
    _videoDecoderConnector.onTextureId.listen((textureId) {
      print('Received texture ID: $textureId');
    });
    await _audioDecoderConnector.initialize();
  }

  Future<void> videoCallBack(String trackId) async {
    await _videoDecoderConnector.setupVideoProcessing(trackId);
  }

  Future<void> audioCallBack() async {
    await _audioDecoderConnector.startAudioProcessing();
  }

  Future<void> _makeCall() async {
    await _remotePeer.connect(
        signalingUrl: _signalingUrl,
        onVideoTrack: videoCallBack,
        onAudioTrack: audioCallBack);
  }

  Future<void> _hangUp() async {
    await _remotePeer.close();
  }

  @override
  void dispose() {
    _remotePeer.dispose();
    _videoDecoderConnector.dispose();
    _audioDecoderConnector.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('WebRTC Stream'),
      ),
      body: OrientationBuilder(
        builder: (context, orientation) {
          return FutureBuilder(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                final views = <Widget>[];
                return orientation == Orientation.portrait
                    ? Column(children: views)
                    : Row(children: views);
              }
              return Center(child: CircularProgressIndicator());
            },
          );
        },
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FutureBuilder(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return FloatingActionButton(
                  onPressed: _inCall ? _hangUp : _makeCall,
                  tooltip: _inCall ? 'Hang Up' : 'Call',
                  child: Icon(_inCall ? Icons.call_end : Icons.phone),
                );
              }
              return Container();
            },
          )
        ],
      ),
    );
  }
}
