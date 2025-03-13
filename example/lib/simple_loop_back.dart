import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'local_peer.dart';
import 'remote_peer.dart';

class LoopBackSample extends StatefulWidget {
  @override
  _LoopBackSampleState createState() => _LoopBackSampleState();
}

class _LoopBackSampleState extends State<LoopBackSample> {
  final LocalPeer _localPeer = LocalPeer();
  final RemotePeer _remotePeer = RemotePeer();

  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  bool _inCall = false;
  bool _micOn = false;
  bool _cameraOn = false;

  @override
  void initState() {
    super.initState();
    initRenderers();
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _cleanUp();
    super.dispose();
  }

  Future<void> initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<void> _makeCall() async {
    await _localPeer.initConnection();
    await _remotePeer.initConnection((RTCTrackEvent event) {
      if (event.track.kind == 'video') {
        setState(() {
          _remoteRenderer.srcObject = event.streams[0];
        });
      }
    });

    _localPeer.connection?.onIceCandidate = (candidate) {
      _remotePeer.connection?.addCandidate(candidate);
    };
    _remotePeer.connection?.onIceCandidate = (candidate) {
      _localPeer.connection?.addCandidate(candidate);
    };

    await _localPeer.startMedia(audio: true, video: true);
    await _localPeer.addTracks();
    await _localPeer.setVideoCodec('h264');
    setState(() {
      _localRenderer.srcObject = _localPeer.stream;
    });

    var offer = await _localPeer.connection!.createOffer();
    await _localPeer.connection?.setLocalDescription(offer);
    await _remotePeer.connection?.setRemoteDescription(offer);

    var answer = await _remotePeer.connection!.createAnswer();
    await _remotePeer.connection?.setLocalDescription(answer);
    await _localPeer.connection?.setRemoteDescription(answer);

    setState(() {
      _inCall = true;
    });
  }

  Future<void> _hangUp() async {
    await _localPeer.close();
    await _remotePeer.close();
    _localRenderer.srcObject = null;
    _remoteRenderer.srcObject = null;
    setState(() {
      _inCall = false;
      _cameraOn = false;
      _micOn = false;
    });
  }

  Future<void> _startVideo() async {
    await _localPeer.startMedia(audio: false, video: true);
    await _localPeer.addTracks();
    setState(() {
      _localRenderer.srcObject = _localPeer.stream;
      _cameraOn = true;
    });
    // trigger renegotiation here if needed
  }

  Future<void> _stopVideo() async {
    await _localPeer.removeTracks(removeVideo: true);
    setState(() {
      _cameraOn = false;
      _localRenderer.srcObject = _localPeer.stream;
    });
    // trigger renegotiation here if needed
  }

  Future<void> _startAudio() async {
    await _localPeer.startMedia(audio: true, video: false);
    await _localPeer.addTracks();
    setState(() {
      _micOn = true;
    });
  }

  Future<void> _stopAudio() async {
    await _localPeer.removeTracks(removeAudio: true);
    setState(() {
      _micOn = false;
    });
  }

  Future<void> _cleanUp() async {
    await _hangUp();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('LoopBack (Cleaned Up)'),
      ),
      body: OrientationBuilder(
        builder: (context, orientation) {
          final views = <Widget>[
            Expanded(child: RTCVideoView(_localRenderer, mirror: true)),
            Expanded(child: RTCVideoView(_remoteRenderer)),
          ];
          return orientation == Orientation.portrait
              ? Column(children: views)
              : Row(children: views);
        },
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FloatingActionButton(
            onPressed: _inCall ? _hangUp : _makeCall,
            tooltip: _inCall ? 'Hang Up' : 'Call',
            child: Icon(_inCall ? Icons.call_end : Icons.phone),
          ),
          SizedBox(width: 8),
          FloatingActionButton(
            onPressed: _micOn ? _stopAudio : _startAudio,
            tooltip: _micOn ? 'Stop Mic' : 'Start Mic',
            child: Icon(_micOn ? Icons.mic : Icons.mic_off),
          ),
          SizedBox(width: 8),
          FloatingActionButton(
            onPressed: _cameraOn ? _stopVideo : _startVideo,
            tooltip: _cameraOn ? 'Stop Video' : 'Start Video',
            child: Icon(_cameraOn ? Icons.videocam : Icons.videocam_off),
          ),
        ],
      ),
    );
  }
}
