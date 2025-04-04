import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../app_logger.dart';
import '../config.dart';
import 'mock_grpc_service.dart';

class StreamInstance {
  final String streamId;
  final AppLogger _logger;
  final MockGrpcService _mockGrpcService;
  final VoidCallback? onStoppedForwarding;
  final VoidCallback? onDisposed;

  WebSocketChannel? _webSocket;
  Completer<void>? _wsConnectCompleter;
  StreamSubscription<Uint8List>? _frameSubscription;
  bool _isDisposing = false;
  bool isWebSocketConnected = false;
  bool _isForwardingActive = false;

  Timer? _inactivityTimer;
  static const Duration _inactivityTimeout = Duration(seconds: 15);

  bool get isForwardingActive => _isForwardingActive;

  StreamInstance(
    this.streamId,
    this._logger,
    this._mockGrpcService, {
    this.onStoppedForwarding,
    this.onDisposed,
  });

  void _setForwardingActive(bool active) {
    if (_isForwardingActive == active) return;
    _isForwardingActive = active;
    _logger.addLog("'$streamId': Forwarding state set to $active");
    if (!active) {
      _cancelInactivityTimer();
      onStoppedForwarding?.call();
    } else {
      // _resetInactivityTimer(); // Timer started in activateFrameForwarding
    }
  }

  void _startInactivityTimer() {
    _cancelInactivityTimer();
    _logger.addLog(
      "'$streamId': Starting inactivity timer (${_inactivityTimeout.inSeconds}s)...",
    );
    _inactivityTimer = Timer(_inactivityTimeout, _handleInactivity);
  }

  void _resetInactivityTimer() {
    if (!_isForwardingActive || _isDisposing || _inactivityTimer == null) {
      return;
    }
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_inactivityTimeout, _handleInactivity);
  }

  void _cancelInactivityTimer() {
    if (_inactivityTimer != null) {
      _inactivityTimer?.cancel();
      _inactivityTimer = null;
    }
  }

  void _handleInactivity() {
    _logger.addLog("'$streamId': Inactivity timer fired.");
    _inactivityTimer = null;
    if (_isForwardingActive && !_isDisposing) {
      _logger.addLog("'$streamId': Inactivity detected. Stopping forwarding.");
      stopFrameForwarding();
    } else {
      _logger.addLog(
        "'$streamId': Inactivity timer fired but no action needed.",
      );
    }
  }

  Future<bool> connectWebSocket() async {
    if (_isDisposing || isWebSocketConnected) return isWebSocketConnected;
    _logger.addLog(
      "'$streamId': Connecting WebSocket to Python: $pythonWsBaseUrl/$streamId...",
    );
    _wsConnectCompleter = Completer<void>();
    try {
      final url = Uri.parse('$pythonWsBaseUrl/$streamId');
      _webSocket = WebSocketChannel.connect(url);
      isWebSocketConnected = false;
      final readyFuture = _webSocket!.ready.timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException("WebSocket ready timeout"),
      );
      _webSocket!.stream.listen(
        (message) =>
            _logger.addLog("'$streamId': WS Received (unexpected): $message"),
        onDone: () {
          isWebSocketConnected = false;
          if (!_isDisposing) {
            _logger.addLog(
              "'$streamId': WS disconnected (onDone). Cleaning up.",
            );
            stopFrameForwarding();
            dispose();
          } else {
            _logger.addLog("'$streamId': WS closed normally during dispose.");
          }
          if (_wsConnectCompleter != null &&
              !_wsConnectCompleter!.isCompleted) {
            _wsConnectCompleter!.completeError(
              StateError("WS closed (onDone)"),
            );
          }
        },
        onError: (error) {
          isWebSocketConnected = false;
          if (!_isDisposing) {
            _logger.addLog("'$streamId': WS Error: $error. Cleaning up.");
            stopFrameForwarding();
            dispose();
          } else {
            _logger.addLog("'$streamId': WS Error during dispose: $error");
          }
          if (_wsConnectCompleter != null &&
              !_wsConnectCompleter!.isCompleted) {
            _wsConnectCompleter!.completeError("WS error: $error");
          }
        },
        cancelOnError: true,
      );
      await readyFuture;
      isWebSocketConnected = true;
      _logger.addLog("'$streamId': WS Connected successfully.");
      if (!_wsConnectCompleter!.isCompleted) _wsConnectCompleter!.complete();
      return true;
    } catch (e) {
      _logger.addLog("'$streamId': Failed to connect WS: $e");
      isWebSocketConnected = false;
      _webSocket = null;
      if (_wsConnectCompleter != null && !_wsConnectCompleter!.isCompleted) {
        _wsConnectCompleter!.completeError("WS connection failed: $e");
      }
      return false;
    }
  }

  Future<bool> ensureWebSocketConnected() async {
    if (isWebSocketConnected && _webSocket != null) return true;
    if (_isDisposing) return false;
    if (_wsConnectCompleter != null && !_wsConnectCompleter!.isCompleted) {
      _logger.addLog("'$streamId': Waiting for existing WS connection...");
      try {
        await _wsConnectCompleter!.future;
        return isWebSocketConnected;
      } catch (e) {
        _logger.addLog("'$streamId': Existing WS connection failed: $e");
        return false;
      }
    }
    return await connectWebSocket();
  }

  Future<RTCSessionDescription?> negotiateWebRTCWithPython(
    RTCSessionDescription clientOffer,
  ) async {
    if (_isDisposing) return null;
    _logger.addLog("'$streamId': Forwarding Client Offer to Python...");
    if (!await ensureWebSocketConnected()) {
      _logger.addLog("'$streamId': WS not connected. Cannot negotiate.");
      return null;
    }
    try {
      final url = Uri.parse('$pythonHttpBaseUrl/offer/$streamId');
      _logger.addLog("'$streamId': POST $url");
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(clientOffer.toMap()),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        _logger.addLog("'$streamId': Received Answer from Python.");
        final answerMap = jsonDecode(response.body);
        return RTCSessionDescription(answerMap['sdp'], answerMap['type']);
      } else {
        String errorBody = response.body;
        try {
          errorBody = jsonDecode(response.body)['error'] ?? errorBody;
        } catch (_) {}
        _logger.addLog(
          "'$streamId': Error getting Answer: ${response.statusCode} - $errorBody",
        );
        throw Exception(
          'Python server error: ${response.statusCode} - $errorBody',
        );
      }
    } catch (e, s) {
      _logger.addLog(
        "'$streamId': Exception negotiating with Python: $e\nStack: $s",
      );
      return null;
    }
  }

  void activateFrameForwarding() {
    if (_isDisposing ||
        _isForwardingActive ||
        !isWebSocketConnected ||
        _webSocket == null) {
      if (_isForwardingActive) {
        _logger.addLog(
          "'$streamId': Warn: activateFrameForwarding called but already active.",
        );
      } else {
        _logger.addLog(
          "'$streamId': Cannot activate frame forwarding (State check failed).",
        );
      }
      return;
    }
    _logger.addLog("'$streamId': Activating frame forwarding...");
    _setForwardingActive(true);
    _startInactivityTimer();

    _frameSubscription?.cancel();
    try {
      final frameStream = _mockGrpcService.getCameraStream(streamId);
      _frameSubscription = frameStream.listen(
        (frameData) {
          if (!_isForwardingActive ||
              _isDisposing ||
              !isWebSocketConnected ||
              _webSocket == null) {
            _logger.addLog(
              "'$streamId': State changed during forwarding loop, stopping.",
            );
            stopFrameForwarding();
            return;
          }
          try {
            _webSocket!.sink.add(frameData);
            _resetInactivityTimer();
          } catch (e) {
            _logger.addLog(
              "'$streamId': Error sending frame via WS: $e. Stopping.",
            );
            stopFrameForwarding();
            if (!_isDisposing) dispose();
          }
        },
        onError: (error) {
          _logger.addLog(
            "'$streamId': Error from Mock GRPC stream: $error. Stopping.",
          );
          stopFrameForwarding();
        },
        onDone: () {
          _logger.addLog("'$streamId': Mock GRPC stream ended. Stopping.");
          stopFrameForwarding();
        },
        cancelOnError: true,
      );
      _logger.addLog(
        "'$streamId': Subscribed to Mock GRPC stream. Forwarding activated.",
      );
    } catch (e) {
      _logger.addLog("'$streamId': Error getting mock camera stream: $e");
      _setForwardingActive(false);
    }
  }

  void stopFrameForwarding() {
    if (!_isForwardingActive &&
        _frameSubscription == null &&
        _inactivityTimer == null) {
      return;
    }
    _logger.addLog("'$streamId': Deactivating frame forwarding...");
    _frameSubscription?.cancel();
    _frameSubscription = null;
    _cancelInactivityTimer();
    _setForwardingActive(false);
    _logger.addLog("'$streamId': Frame forwarding deactivated.");
  }

  Future<void> dispose() async {
    if (_isDisposing) return;
    _isDisposing = true;
    _logger.addLog("'$streamId': Disposing stream instance...");
    stopFrameForwarding();

    if (_wsConnectCompleter != null && !_wsConnectCompleter!.isCompleted) {
      _wsConnectCompleter!.completeError(
        StateError("Disposed before WS ready"),
      );
      _logger.addLog("'$streamId': Cancelled pending WS completer.");
    }

    final ws = _webSocket;
    _webSocket = null;
    isWebSocketConnected = false;
    if (ws != null) {
      _logger.addLog("'$streamId': Closing WebSocket sink...");
      try {
        await ws.sink
            .close(status.goingAway, 'Disposing')
            .timeout(const Duration(seconds: 2));
        _logger.addLog("'$streamId': WebSocket sink closed.");
      } catch (e) {
        _logger.addLog("'$streamId': Error closing WebSocket sink: $e");
      }
    }

    _logger.addLog("'$streamId': Stream instance dispose complete.");
    onDisposed?.call();
  }
}
