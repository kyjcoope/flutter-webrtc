import 'dart:async';
import 'dart:typed_data';

import '../app_logger.dart';

class MockGrpcService {
  final AppLogger _logger;
  final Map<String, String> _mockUsers = {'user': 'pass'};
  final List<String> _mockCameraIds = ['camera1', 'garageCam', 'frontDoor'];
  final Map<String, StreamController<Uint8List>> _streamControllers = {};
  final Map<String, Timer> _streamTimers = {};
  final Map<String, int> _frameCounters = {}; // Track frame count per stream

  MockGrpcService(this._logger);

  Future<bool> login(String username, String password) async {
    _logger.addLog("Mock GRPC: login attempt for '$username'");
    await Future.delayed(const Duration(milliseconds: 500));
    final bool success = _mockUsers[username] == password;
    _logger.addLog("Mock GRPC: login ${success ? 'successful' : 'failed'}");
    return success;
  }

  Future<List<String>> getCameraList() async {
    _logger.addLog("Mock GRPC: getCameraList called");
    await Future.delayed(const Duration(milliseconds: 300));
    _logger.addLog("Mock GRPC: returning camera list: $_mockCameraIds");
    return List.unmodifiable(_mockCameraIds);
  }

  Stream<Uint8List> getCameraStream(String streamId) {
    _logger.addLog("Mock GRPC: getCameraStream requested for '$streamId'");

    if (_streamControllers.containsKey(streamId)) {
      _logger.addLog("Mock GRPC: Returning existing stream for '$streamId'");
      return _streamControllers[streamId]!.stream;
    }

    if (!_mockCameraIds.contains(streamId)) {
      _logger.addLog(
        "Mock GRPC: Error - Invalid streamId '$streamId' requested.",
      );
      final errorController = StreamController<Uint8List>();
      errorController.addError(ArgumentError("Invalid stream ID: $streamId"));
      errorController.close();
      return errorController.stream;
    }

    _logger.addLog("Mock GRPC: Creating new mock data stream for '$streamId'");
    final controller = StreamController<Uint8List>(
      onCancel: () {
        _logger.addLog(
          "Mock GRPC: Stream for '$streamId' cancelled by listener.",
        );
        _stopStreamGeneration(streamId);
      },
    );

    _streamControllers[streamId] = controller;
    _frameCounters[streamId] = 0; // Initialize frame counter
    _startStreamGeneration(streamId, controller);

    return controller.stream;
  }

  void _startStreamGeneration(
    String streamId,
    StreamController<Uint8List> controller,
  ) {
    _logger.addLog(
      "Mock GRPC: Starting frame generation timer for '$streamId'",
    );
    final idrFrameData = Uint8List.fromList([
      0x00,
      0x00,
      0x00,
      0x01,
      0x65,
      0x88,
      0x84,
      0x01,
      0x01,
      0x02,
      0x03,
      0xFF,
    ]);
    final pFrameData = Uint8List.fromList([
      0x00,
      0x00,
      0x00,
      0x01,
      0x41,
      0x9A,
      0xBC,
      0xDE,
      0xF0,
      0x12,
      0x34,
    ]);
    const frameInterval = Duration(milliseconds: 33);

    // Ensure no existing timer before starting a new one
    _streamTimers[streamId]?.cancel();

    _streamTimers[streamId] = Timer.periodic(frameInterval, (timer) {
      if (!_streamControllers.containsKey(streamId) || controller.isClosed) {
        _logger.addLog(
          "Mock GRPC: Stopping timer for '$streamId', controller closed or removed.",
        );
        timer.cancel();
        _streamTimers.remove(streamId);
        _frameCounters.remove(streamId);
        // Ensure controller is closed if not already
        if (_streamControllers.containsKey(streamId) && !controller.isClosed) {
          controller.close();
          _streamControllers.remove(streamId);
        }
        return;
      }

      int currentFrameCount = _frameCounters[streamId] ?? 0;
      final bool isKeyFrame = (currentFrameCount % 30 == 0);
      final frameToSend = isKeyFrame ? idrFrameData : pFrameData;

      try {
        // _logger.addLog("Mock GRPC: Sending ${isKeyFrame ? 'IDR' : 'P'} frame ($currentFrameCount) for '$streamId'"); // Verbose
        controller.add(frameToSend);
        _frameCounters[streamId] = currentFrameCount + 1;
      } catch (e) {
        _logger.addLog(
          "Mock GRPC: Error adding frame to controller for '$streamId': $e. Stopping generation.",
        );
        _stopStreamGeneration(streamId); // Stop on error
      }
    });
  }

  void _stopStreamGeneration(String streamId) {
    _logger.addLog("Mock GRPC: Stopping stream generation for '$streamId'");
    _streamTimers.remove(streamId)?.cancel();
    _streamControllers.remove(streamId)?.close(); // Close the controller
    _frameCounters.remove(streamId);
  }

  // Optional: Method to stop all mock streams if needed during shutdown
  void disposeAllMockStreams() {
    _logger.addLog("Mock GRPC: Disposing all mock streams...");
    final streamIds = List<String>.from(_streamControllers.keys); // Copy keys
    for (final id in streamIds) {
      _stopStreamGeneration(id);
    }
    _logger.addLog("Mock GRPC: All mock streams disposed.");
  }
}
