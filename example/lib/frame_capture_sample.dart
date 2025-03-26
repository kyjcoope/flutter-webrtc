import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class FrameCaptureSample extends StatefulWidget {
  @override
  _FrameCaptureSampleState createState() => _FrameCaptureSampleState();
}

class _FrameCaptureSampleState extends State<FrameCaptureSample> {
  final WebRTCLocalPeer _localPeer = WebRTCLocalPeer();
  final WebRTCRemotePeer _remotePeer = WebRTCRemotePeer();
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();

  bool _inCall = false;
  StreamSubscription? _videoSubscription;
  StreamSubscription? _audioSubscription;

  @override
  void initState() {
    super.initState();
    _setupFrameListeners();
  }

  void _setupFrameListeners() {
    _videoSubscription = _remotePeer.onVideoFrame.listen((frame) {
      _addLog(
          'Received video frame: ${frame.width}x${frame.height}, size: ${frame.buffer.length} bytes');
    });

    _audioSubscription = _remotePeer.onAudioFrame.listen((sample) {
      _addLog(
          'Received audio sample: channels=${sample.channels}, size=${sample.buffer.length} bytes');
    });
  }

  @override
  void dispose() {
    _videoSubscription?.cancel();
    _audioSubscription?.cancel();
    _hangUp();
    _scrollController.dispose();
    super.dispose();
  }

  void _addLog(String message) {
    setState(() {
      _logs.add("[${DateTime.now().toString().split('.').first}] $message");
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

    await _localPeer.initialize();
    await _remotePeer.initialize();

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
    });
    _addLog('Call ended');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Frame Capture Demo'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Frame Capture Test',
              style: Theme.of(context).textTheme.titleLarge,
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
