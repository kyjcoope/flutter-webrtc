import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/bindings/media_frame.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BypassTestApp());
}

class BypassTestApp extends StatelessWidget {
  const BypassTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: BypassTestPage(),
    );
  }
}

class BypassTestPage extends StatefulWidget {
  const BypassTestPage({super.key});

  @override
  State<BypassTestPage> createState() => _BypassTestPageState();
}

class _BypassTestPageState extends State<BypassTestPage> {
  RTCPeerConnection? _pcSender;
  RTCPeerConnection? _pcReceiver;
  MediaStream? _localStream;

  //final WebRTCMediaStreamer _streamer = WebRTCMediaStreamer();

  StreamSubscription<EncodedVideoFrame>? _frameSub;
  String? _remoteTrackId;
  int _frameCount = 0;
  bool _isRunning = false;

  @override
  void dispose() {
    _stopTest();
    super.dispose();
  }

  Future<void> _startTest() async {
    if (_isRunning) return;
    setState(() => _isRunning = true);

    final mediaConstraints = <String, dynamic>{
      'audio': false,
      'video': {
        'facingMode': 'user',
      },
    };

    final stream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    _localStream = stream;

    final config = <String, dynamic>{
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
      'sdpSemantics': 'plan-b', // <--- ADD THIS LINE
    };

    final pcConstraints = <String, dynamic>{
      'mandatory': {},
      'optional': [],
    };

    final pc1 = await createPeerConnection(config, pcConstraints);
    final pc2 = await createPeerConnection(config, pcConstraints);

    _pcSender = pc1;
    _pcReceiver = pc2;

    pc1.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null) {
        pc2.addCandidate(candidate);
      }
    };

    pc2.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null) {
        pc1.addCandidate(candidate);
      }
    };

    await pc1.addStream(stream);

    pc2.onTrack = (RTCTrackEvent event) async {
      final track = event.track;
      if (track.kind == 'video') {
        _remoteTrackId = track.id;
        debugPrint('Remote video track added: ${track.id}');
        //final framesStream = await _streamer.videoFramesFrom(track.id ?? '');

        // await _frameSub?.cancel();
        // _frameSub = framesStream.listen((EncodedVideoFrame frame) {
        //   _frameCount++;
        //   debugPrint(
        //     'Bypass frame $_frameCount: '
        //     '${frame.width}x${frame.height}, '
        //     'time=${frame.frameTime}, '
        //     'len=${frame.buffer.lengthInBytes}, '
        //     'codecType=${frame.codecType}, '
        //     'frameType=${frame.frameType}',
        //   );
        //   setState(() {});
        // });
      }
    };

    final offer = await pc1.createOffer({
      'offerToReceiveAudio': false,
      'offerToReceiveVideo': true,
    });
    await pc1.setLocalDescription(offer);
    await pc2.setRemoteDescription(offer);

    final answer = await pc2.createAnswer({
      'offerToReceiveAudio': false,
      'offerToReceiveVideo': true,
    });
    await pc2.setLocalDescription(answer);
    await pc1.setRemoteDescription(answer);
  }

  Future<void> _stopTest() async {
    await _frameSub?.cancel();
    _frameSub = null;

    if (_remoteTrackId != null) {
      //_streamer.disposeVideoStream(_remoteTrackId!);
      _remoteTrackId = null;
    }

    await _pcSender?.close();
    await _pcReceiver?.close();
    _pcSender = null;
    _pcReceiver = null;

    await _localStream?.dispose();
    _localStream = null;

    setState(() {
      _isRunning = false;
      _frameCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bypass Test')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${_isRunning ? "Running" : "Stopped"}'),
            const SizedBox(height: 8),
            Text('Frames received via bypass: $_frameCount'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isRunning ? null : _startTest,
              child: const Text('Start bypass test'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isRunning ? _stopTest : null,
              child: const Text('Stop'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Notes:\n'
              '- This app does not render video.\n'
              '- Watch the logcat/Flutter logs for "Bypass frame ..." lines.\n'
              '- Those log entries confirm that VideoDecoderBypass is being used.',
            ),
          ],
        ),
      ),
    );
  }
}
