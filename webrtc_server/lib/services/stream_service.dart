import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../app_logger.dart';
import 'mock_grpc_service.dart';
import 'stream_instance.dart';

class StreamService extends ChangeNotifier {
  final AppLogger _logger;
  final MockGrpcService _mockGrpcService;
  final Map<String, StreamInstance> _managedStreams = {};
  List<String> _availableStreamIds = [];
  bool _isDisposed = false;

  StreamService(this._logger, this._mockGrpcService);

  void setAvailableStreams(List<String> streamIds) {
    _availableStreamIds = List.unmodifiable(streamIds);
    _logger.addLog(
      "StreamService updated available streams: $_availableStreamIds",
    );
  }

  bool isStreamAvailable(String streamId) =>
      _availableStreamIds.contains(streamId);
  List<String> getManagedStreamIds() => _managedStreams.keys.toList();
  List<String> getActiveForwardingStreamIds() =>
      _managedStreams.entries
          .where((entry) => entry.value.isForwardingActive)
          .map((entry) => entry.key)
          .toList();

  void _handleInstanceStoppedForwarding(String streamId) {
    _logger.addLog(
      "StreamService notified that '$streamId' stopped forwarding.",
    );
    if (_managedStreams.containsKey(streamId)) {
      notifyListeners();
    } else {
      _logger.addLog(
        "Warn: '$streamId' stopped forwarding but was already removed.",
      );
    }
  }

  void _handleInstanceDisposed(String streamId) {
    _logger.addLog(
      "StreamService notified that '$streamId' instance was disposed.",
    );
    if (_managedStreams.containsKey(streamId)) {
      _logger.addLog(
        "Warn: Removing '$streamId' from managed streams during disposed callback.",
      );
      _managedStreams.remove(streamId);
      notifyListeners();
    }
  }

  Future<void> stopAndRemoveManagedStream(String streamId) async {
    if (_isDisposed) return;
    final instance = _managedStreams.remove(streamId);
    if (instance != null) {
      _logger.addLog("Stopping and removing managed stream '$streamId'...");
      notifyListeners();
      await instance.dispose();
      _logger.addLog("Managed instance for '$streamId' stopped and disposed.");
    } else {
      _logger.addLog("Warn: Attempted to stop non-managed stream '$streamId'.");
    }
  }

  Future<RTCSessionDescription?> negotiateAndActivateStream(
    String streamId,
    RTCSessionDescription clientOffer,
  ) async {
    if (_isDisposed) return null;
    if (!isStreamAvailable(streamId)) {
      _logger.addLog(
        "Error: Cannot negotiate for unavailable stream '$streamId'.",
      );
      return null;
    }

    StreamInstance? instance = _managedStreams[streamId];
    bool instanceCreated = false;

    if (instance == null) {
      _logger.addLog("'$streamId' not managed. Creating instance on demand...");
      instance = StreamInstance(
        streamId,
        _logger,
        _mockGrpcService,
        onStoppedForwarding: () => _handleInstanceStoppedForwarding(streamId),
        onDisposed: () => _handleInstanceDisposed(streamId),
      );
      _managedStreams[streamId] = instance;
      instanceCreated = true;
      bool connected = await instance.connectWebSocket();
      if (!connected) {
        _logger.addLog(
          "Error: Failed WS connect for on-demand instance '$streamId'.",
        );
        await instance.dispose();
        if (_managedStreams.containsKey(streamId))
          _managedStreams.remove(streamId);
        notifyListeners();
        return null;
      }
      _logger.addLog("'$streamId': On-demand instance created/WS connected.");
      notifyListeners();
    } else {
      _logger.addLog("'$streamId': Using existing managed instance.");
      if (!await instance.ensureWebSocketConnected()) {
        _logger.addLog(
          "Error: Existing instance '$streamId' WS connection failed.",
        );
        await stopAndRemoveManagedStream(streamId);
        return null;
      }
    }

    final answer = await instance.negotiateWebRTCWithPython(clientOffer);
    if (answer != null) {
      _logger.addLog("'$streamId': Negotiation OK. Activating forwarding.");
      instance.activateFrameForwarding();
      notifyListeners();
    } else {
      _logger.addLog(
        "Warn: Negotiation failed for '$streamId'. Forwarding not activated.",
      );
      if (instanceCreated) {
        await stopAndRemoveManagedStream(streamId);
      }
    }
    return answer;
  }

  void disposeAllStreams() {
    if (_isDisposed) return;
    _isDisposed = true;
    _logger.addLog("Disposing all managed stream instances...");
    final instancesToDispose = List<StreamInstance>.from(
      _managedStreams.values,
    );
    _managedStreams.clear();
    notifyListeners();

    final disposeFutures =
        instancesToDispose.map((instance) {
          _logger.addLog(
            "Requesting dispose for managed stream '${instance.streamId}'...",
          );
          return instance.dispose();
        }).toList();

    Future.wait(disposeFutures)
        .then((_) {
          _logger.addLog(
            "All managed stream instances dispose process completed.",
          );
        })
        .catchError((e) {
          _logger.addLog("Error during bulk managed stream disposal: $e");
        });
    _mockGrpcService.disposeAllMockStreams();
  }
}
