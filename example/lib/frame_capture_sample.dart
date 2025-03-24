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

  // Add renderer for remote audio/video
  //final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  MediaStream? _remoteStream;

  // Add volume control
  double _volume = 0.7;

  Timer? _frameTimer;
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();

  bool _inCall = false;
  bool _capturingFrames = false;

  @override
  void initState() {
    super.initState();
    _initRenderers();
  }

  Future<void> _initRenderers() async {
    //await _remoteRenderer.initialize();
    _addLog('Renderer initialized');
  }

  @override
  void dispose() {
    _stopFrameCapture();
    _hangUp();
    //_remoteRenderer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Volume control for device - real volume must be controlled from device
  void _updateVolume() {
    setState(() {
      // Volume changes need to be handled by system volume controls
      _addLog('Volume set to: ${(_volume * 100).toInt()}%');
    });
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

    _frameTimer = Timer.periodic(Duration(milliseconds: 10), (timer) {
      try {
        // Get track IDs from the local peer streams
        // String? videoTrackId;
        // if (_localPeer.stream != null) {
        //   var videoTracks = _localPeer.stream!.getVideoTracks();
        //   if (videoTracks.isNotEmpty) {
        //     videoTrackId = videoTracks[0].id;
        //   }
        // }

        // // Capture video frames
        // if (videoTrackId != null) {
        //   var videoFrame = popVideoFrame(videoTrackId);
        //   if (videoFrame != null) {}
        // }

        // Capture audio frames (using the constant audio buffer key)
        var audioFrame = popAudioFrame();
        print('Audio frame: ${audioFrame?.buffer.length}');
      } catch (e) {
        print('Error capturing frames: $e');
      }
    });

    await _remotePeer.initConnection((RTCTrackEvent event) async {
      _addLog('Remote track received: ${event.track.kind}');

      try {
        // Create a stream to hold the track if needed
        if (_remoteStream == null) {
          // Use stream from event if available, otherwise create new
          if (event.streams.isNotEmpty) {
            _remoteStream = event.streams[0];
            _addLog('Using existing stream from event');
          } else {
            _remoteStream = await createLocalMediaStream('remote_stream');
            _addLog('Created new media stream');
          }

          // Set stream to renderer to activate audio pipeline
          //_remoteRenderer.srcObject = _remoteStream;

          // Enable speaker (important for audio)
          try {
            await Helper.setSpeakerphoneOn(true);
            _addLog('Speaker enabled');
          } catch (e) {
            _addLog('Error enabling speaker: $e');
          }
        }

        // Add the track to our stream if not already there
        if (!_remoteStream!.getTracks().contains(event.track)) {
          await _remoteStream!.addTrack(event.track);
          _addLog('Added track to stream');
        }

        if (event.track.kind == 'video') {
          _addLog('Video track ID: ${event.track.id}');
        } else if (event.track.kind == 'audio') {
          _addLog('Audio track ID: ${event.track.id}');

          // Try direct audio track handling for clearer playback
          try {
            // Force audio track directly to renderer
            //_remoteRenderer.srcObject = _remoteStream;
            _addLog('Direct audio track handling applied');
          } catch (e) {
            _addLog('Error in audio track handling: $e');
          }
        }
      } catch (e) {
        _addLog('Error handling remote track: $e');
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

    // Clear remote stream
    _remoteStream = null;
    //_remoteRenderer.srcObject = null;

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
          // Display the video renderer as main content
          Expanded(
            flex: 3,
            child: Container(
              margin: EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black),
              ),
              child: Container(),
            ),
          ),

          // Volume control slider (visual only - system controls actual volume)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: Row(
              children: [
                Icon(Icons.volume_down),
                Expanded(
                  child: Slider(
                    value: _volume,
                    min: 0.0,
                    max: 1.0,
                    onChanged: (value) {
                      setState(() => _volume = value);
                      _updateVolume();
                    },
                  ),
                ),
                Icon(Icons.volume_up),
              ],
            ),
          ),

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
            flex: 2,
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
