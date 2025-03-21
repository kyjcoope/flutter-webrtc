import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/bindings/native_bindings.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'local_peer.dart';
import 'remote_peer.dart';

class FrameCaptureSample extends StatefulWidget {
  @override
  _FrameCaptureSampleState createState() => _FrameCaptureSampleState();
}

class _FrameCaptureSampleState extends State<FrameCaptureSample> {
  final LocalPeer _localPeer = LocalPeer();
  final RemotePeer _remotePeer = RemotePeer();

  Timer? _frameTimer;
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();

  bool _inCall = false;
  bool _capturingFrames = false;

  @override
  void dispose() {
    _stopFrameCapture();
    _hangUp();
    _scrollController.dispose();
    super.dispose();
  }

  void _addLog(String message) {
    setState(() {
      _logs.add("[${DateTime.now().toString().split('.').first}] $message");
      // Keep log size reasonable
      if (_logs.length > 100) {
        _logs.removeAt(0);
      }
    });

    // Scroll to bottom
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
    await _localPeer.initConnection();
    await _remotePeer.initConnection((RTCTrackEvent event) {
      _addLog('Remote track received: ${event.track.kind}');
      if (event.track.kind == 'video') {
        _addLog('Video track ID: ${event.track.id}');
      }
    });

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
    var offer = await _localPeer.connection!.createOffer();
    await _localPeer.connection?.setLocalDescription(offer);
    await _remotePeer.connection?.setRemoteDescription(offer);

    _addLog('Creating answer...');
    var answer = await _remotePeer.connection!.createAnswer();
    await _remotePeer.connection?.setLocalDescription(answer);
    await _localPeer.connection?.setRemoteDescription(answer);

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
    });
    _addLog('Call ended');
  }

  void _startFrameCapture() {
    if (_frameTimer != null) return;

    _addLog('Starting frame capture');
    setState(() {
      _capturingFrames = true;
    });

    _frameTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      try {
        // Get track IDs from the local peer streams
        String? videoTrackId;
        if (_localPeer.stream != null) {
          var videoTracks = _localPeer.stream!.getVideoTracks();
          if (videoTracks.isNotEmpty) {
            videoTrackId = videoTracks[0].id;
          }
        }

        // Capture video frames
        if (videoTrackId != null) {
          var videoFrame = popVideoFrame(videoTrackId);
          if (videoFrame != null) {
            _addLog(
                'Video frame: ${videoFrame.width}x${videoFrame.height}, ${videoFrame.buffer.length} bytes');
          }
        }

        // Capture audio frames (using the constant audio buffer key)
        var audioFrame = popAudioFrame();
        if (audioFrame != null) {
          _addLog(
              'Audio frame: ${audioFrame.sampleRate}Hz, ${audioFrame.channels} channels, ${audioFrame.buffer.length} bytes');
        }
      } catch (e) {
        _addLog('Error capturing frames: $e');
      }
    });
  }

  void _stopFrameCapture() {
    _frameTimer?.cancel();
    _frameTimer = null;
    setState(() {
      _capturingFrames = false;
    });
    _addLog('Frame capture stopped');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Frame Capture Demo'),
      ),
      body: Column(
        children: [
          // Control buttons
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _inCall ? _hangUp : _makeCall,
                  child: Text(_inCall ? 'Hang Up' : 'Make Call'),
                ),
                ElevatedButton(
                  onPressed: !_inCall
                      ? null
                      : (_capturingFrames
                          ? _stopFrameCapture
                          : _startFrameCapture),
                  child:
                      Text(_capturingFrames ? 'Stop Capture' : 'Start Capture'),
                ),
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

          // Log display area
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
