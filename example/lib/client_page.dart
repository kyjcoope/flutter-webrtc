import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;

import 'audio/audio_decoder_connector.dart';
import 'video/video_decoder_connector.dart';

const String dartBackendHost = '192.168.5.238';
const int dartBackendApiPort = 8081;
const String dartApiBaseUrl = 'http://$dartBackendHost:$dartBackendApiPort';

class ClientPage extends StatefulWidget {
  const ClientPage({super.key});
  @override
  State<ClientPage> createState() => _ClientPageState();
}

class _ClientPageState extends State<ClientPage> {
  String _status = 'Idle';
  List<String> _streamIds = [];
  String? _selectedStreamId;
  bool _isLoadingStreams = false;
  bool _isConnecting = false;
  bool _inCall = false;
  late final WebRTCRemotePeer _remotePeer;
  String? _receivedVideoTrackId;
  bool _receivedAudio = false;
  StreamSubscription? _connectionStateSubscription;

  final VideoDecoderConnector _videoDecoderConnector = VideoDecoderConnector();
  final AudioDecoderConnector _audioDecoderConnector = AudioDecoderConnector();

  @override
  void initState() {
    super.initState();
    _remotePeer = WebRTCRemotePeer();
    _listenToConnectionState();
    _fetchStreams();
    _init();
  }

  @override
  void dispose() {
    _connectionStateSubscription?.cancel();
    _remotePeer.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _videoDecoderConnector.initialize();
    _videoDecoderConnector.onTextureId.listen((textureId) {
      print('Received texture ID: $textureId');
    });
    await _audioDecoderConnector.initialize();
  }

  void _listenToConnectionState() {
    _connectionStateSubscription =
        _remotePeer.onConnectionStateChange.listen((PeerConnectionState state) {
      print('Mobile Client Received connection state: $state');
      if (!mounted) return;
      bool wasInCall = _inCall;
      bool currentInCall = (state == PeerConnectionState.connected);
      setState(() {
        _inCall = currentInCall;
        _isConnecting = (state == PeerConnectionState.connecting);
        switch (state) {
          case PeerConnectionState.initial:
            _status = "Idle";
            if (wasInCall) _resetTrackInfo();
            break;
          case PeerConnectionState.connecting:
            _status = "Connecting to '${_selectedStreamId ?? ''}'...";
            break;
          case PeerConnectionState.connected:
            _status = "Connected to '${_selectedStreamId ?? ''}'";
            break;
          case PeerConnectionState.disconnected:
            _status = "Disconnected from '${_selectedStreamId ?? ''}'";
            if (wasInCall) _handleDisconnect();
            break;
          case PeerConnectionState.failed:
            _status = "Connection Failed for '${_selectedStreamId ?? ''}'";
            if (wasInCall || _isConnecting) _handleDisconnect();
            break;
          case PeerConnectionState.closed:
            _status = "Connection Closed for '${_selectedStreamId ?? ''}'";
            if (wasInCall || _isConnecting) _handleDisconnect();
            break;
        }
      });
    }, onError: (error) {
      print("Connection state stream error: $error");
      if (mounted) {
        setState(() {
          _status = "Error: $error";
          _handleDisconnect();
        });
      }
    });
  }

  void _resetTrackInfo() {
    if (mounted) {
      setState(() {
        _receivedVideoTrackId = null;
        _receivedAudio = false;
      });
    }
  }

  Future<void> _fetchStreams() async {
    if (!mounted) return;
    setState(() {
      _isLoadingStreams = true;
      _status = 'Fetching streams...';
      _streamIds = [];
      _selectedStreamId = null;
    });
    try {
      final url = Uri.parse('$dartApiBaseUrl/streams');
      print("Mobile Client: Fetching streams from $url");
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> streams = data['streams'] ?? [];
        print("Mobile Client: Received streams: $streams");
        setState(() {
          _streamIds = streams.map((e) => e.toString()).toList();
          _status =
              _streamIds.isEmpty ? 'No streams available.' : 'Select a stream';
        });
      } else {
        print(
            'Error fetching streams: ${response.statusCode} ${response.reasonPhrase}');
        setState(() {
          _status = 'Error fetching streams: ${response.statusCode}';
        });
      }
    } catch (e) {
      print('Failed to fetch streams: $e');
      if (mounted) {
        setState(() {
          _status = 'Failed to fetch streams: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingStreams = false;
        });
      }
    }
  }

  Future<void> _videoCallback(String trackId) async {
    print('Mobile Client: Video track received callback: $trackId');
    await _videoDecoderConnector.setupVideoProcessing(trackId);
    if (mounted) {
      setState(() {
        _receivedVideoTrackId = trackId;
        if (_isConnecting || _inCall) {
          _status = "Connected (Video OK)";
        }
      });
    }
  }

  Future<void> _audioCallback() async {
    print('Mobile Client: Audio track received callback');
    await _audioDecoderConnector.startAudioProcessing();
    if (mounted) {
      setState(() {
        _receivedAudio = true;
        if (_isConnecting || _inCall) {
          _status = "Connected (Video/Audio OK)";
        }
      });
    }
  }

  Future<void> _makeCall() async {
    if (_inCall || _isConnecting) return;
    if (_selectedStreamId == null) {
      print("Mobile Client: No stream selected.");
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a stream first!')));
      return;
    }
    _resetTrackInfo();
    setState(() {
      _isConnecting = true;
      _status = "Initiating connection to '$_selectedStreamId'...";
    });
    final signalingUrl = '$dartApiBaseUrl/connect/$_selectedStreamId';
    print(
        "Mobile Client: Calling _remotePeer.connect with Dart Backend URL: $signalingUrl");
    try {
      await _remotePeer.connect(
        signalingUrl: signalingUrl,
        onVideoTrack: _videoCallback,
        onAudioTrack: _audioCallback,
      );
      print(
          "Mobile Client: _remotePeer.connect returned (waiting for connection state change)");
    } catch (e) {
      print('Error initiating call in UI: $e');
      if (mounted) {
        setState(() {
          _status = 'Error starting call: $e';
          _isConnecting = false;
          _handleDisconnect();
        });
      }
    }
  }

  Future<void> _hangUp() async {
    if (!_inCall && !_isConnecting) return;
    print("Mobile Client: Hangup requested.");
    setState(() {
      _status = "Disconnecting...";
    });
    try {
      await _remotePeer.close();
      print("Mobile Client: _remotePeer.close completed.");
    } catch (e) {
      print('Error during hangup: $e');
      if (mounted) {
        setState(() {
          _status = "Error disconnecting: $e";
        });
      }
    } finally {
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    if (mounted) {
      print("Mobile Client: Handling disconnect state update in UI.");
      setState(() {
        _inCall = false;
        _isConnecting = false;
        _resetTrackInfo();
        if (!_status.contains("Failed") &&
            !_status.contains("Closed") &&
            !_status.contains("Disconnected")) {
          _status = "Disconnected";
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mobile WebRTC Client'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh Stream List',
              onPressed: (_isLoadingStreams || _isConnecting || _inCall)
                  ? null
                  : _fetchStreams,
              disabledColor: Colors.grey)
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              if (_isLoadingStreams)
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.0),
                    child: CircularProgressIndicator())
              else if (_streamIds.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: DropdownButton<String>(
                    value: _selectedStreamId,
                    hint: const Text('Select a Camera Stream'),
                    isExpanded: true,
                    items: _streamIds
                        .map((String id) => DropdownMenuItem<String>(
                            value: id,
                            child: Text(id, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: _inCall || _isConnecting
                        ? null
                        : (String? newValue) {
                            if (newValue != _selectedStreamId) {
                              setState(() {
                                _selectedStreamId = newValue;
                                _status = newValue != null
                                    ? "Ready to connect to '$newValue'"
                                    : 'Select a stream';
                                _resetTrackInfo();
                              });
                            }
                          },
                  ),
                )
              else
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20.0),
                    child: Text(
                        _status.startsWith('Error') ||
                                _status.startsWith('Failed')
                            ? _status
                            : 'No streams available.\nIs the Dart backend service running?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: _status.startsWith('Error') ||
                                    _status.startsWith('Failed')
                                ? Theme.of(context).colorScheme.error
                                : null))),
              const SizedBox(height: 20),
              Card(
                elevation: 2.0,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Status: $_status',
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center),
                      const SizedBox(height: 10),
                      Text(
                          _receivedVideoTrackId != null
                              ? "Video Track: Received"
                              : "Video Track: Waiting...",
                          style: TextStyle(
                              color: _receivedVideoTrackId != null
                                  ? Colors.green.shade700
                                  : Colors.orange.shade700)),
                      Text(
                          _receivedAudio
                              ? "Audio Track: Received"
                              : "Audio Track: Waiting...",
                          style: TextStyle(
                              color: _receivedAudio
                                  ? Colors.green.shade700
                                  : Colors.orange.shade700)),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: FloatingActionButton.extended(
                  onPressed: (_isLoadingStreams ||
                          _selectedStreamId == null ||
                          _isConnecting)
                      ? null
                      : (_inCall ? _hangUp : _makeCall),
                  tooltip: _inCall ? 'Hang Up' : 'Call Selected Stream',
                  backgroundColor:
                      _inCall ? Colors.red.shade700 : Colors.green.shade700,
                  foregroundColor: Colors.white,
                  icon: Icon(_inCall ? Icons.call_end : Icons.phone),
                  label: Text(_inCall ? 'Hang Up' : 'Call'),
                  disabledElevation: 0,
                  elevation: 4.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
