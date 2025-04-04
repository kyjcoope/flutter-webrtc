import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_logger.dart';
import '../config.dart';
import '../services/api_service.dart';
import '../services/mock_grpc_service.dart';
import '../services/stream_service.dart';

class BackendServicePage extends StatefulWidget {
  const BackendServicePage({super.key});

  @override
  State<BackendServicePage> createState() => _BackendServicePageState();
}

class _BackendServicePageState extends State<BackendServicePage> {
  ApiService? _apiService;
  MockGrpcService? _mockGrpcService;
  late AppLogger _logger;
  bool _isInitialized = false;
  List<String> _availableStreamIds = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        _logger = context.read<AppLogger>();
        _logger.addLog("Initializing Backend Service Page...");

        _mockGrpcService = context.read<MockGrpcService>();
        final streamService = context.read<StreamService>();

        _apiService = ApiService(_logger, streamService, _mockGrpcService!);

        try {
          await _apiService!.start();
          await _fetchAvailableStreams(streamService);
          setState(() {
            _isInitialized = true;
          });
          _logger.addLog("Backend Service Page Initialized Successfully.");
        } catch (e) {
          _logger.addLog("Error during Backend Service initialization: $e");
          setState(() {
            _isInitialized = false;
          });
        }
      }
    });
  }

  Future<void> _fetchAvailableStreams(StreamService streamService) async {
    _logger.addLog("Fetching available camera list...");
    try {
      final streamIds = await _mockGrpcService!.getCameraList();
      _logger.addLog("Received available streams: $streamIds");
      if (mounted) {
        setState(() {
          _availableStreamIds = streamIds;
        });
        streamService.setAvailableStreams(_availableStreamIds);
      }
      _logger.addLog("Available streams updated.");
    } catch (e) {
      _logger.addLog("Error fetching available streams: $e");
      if (mounted) {
        setState(() {
          _availableStreamIds = [];
        });
        streamService.setAvailableStreams([]);
      }
    }
  }

  @override
  void dispose() {
    _logger.addLog("Disposing BackendServicePage...");
    _apiService
        ?.stop()
        .then((_) => _logger.addLog("API Service stopped."))
        .catchError((e) => _logger.addLog("Error stopping API service: $e"));
    context.read<StreamService>().disposeAllStreams();
    _logger.addLog("Stream service disposal requested via Provider context.");
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logger = context.watch<AppLogger>();
    final streamService = context.watch<StreamService>(); // Watch for changes
    final apiService = _apiService;

    String apiStatus = "API Server Starting...";
    if (apiService != null) {
      if (apiService.isRunning) {
        apiStatus =
            "API Listening on http://${apiService.address?.host}:${apiService.port}";
      } else if (apiService.error != null) {
        apiStatus = "API Server Failed: ${apiService.error}";
      } else {
        apiStatus = "API Server Stopped.";
      }
    }

    // Get lists directly from watched service
    final managedStreams = streamService.getManagedStreamIds();
    final forwardingStreams = streamService.getActiveForwardingStreamIds();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dart Backend Service Status'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'Fetch Available Streams',
            onPressed:
                _isInitialized
                    ? () => _fetchAvailableStreams(streamService)
                    : null,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear Logs',
            onPressed: logger.clearLogs,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child:
            !_isInitialized
                ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text("Initializing..."),
                    ],
                  ),
                )
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Service Status:",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(apiStatus, style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      " Python Backend: $pythonHttpBaseUrl",
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      " Available Streams (${_availableStreamIds.length}):",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    _availableStreamIds.length <= 10
                        ? Text(
                          "  ${_availableStreamIds.join(', ')}",
                          style: const TextStyle(fontSize: 13),
                        )
                        : Text(
                          "  (${_availableStreamIds.length} streams)",
                          style: const TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    const SizedBox(height: 4),
                    Text(
                      " Managed Streams:",
                      style: Theme.of(context).textTheme.titleMedium,
                    ), // Simplified label
                    managedStreams.isEmpty
                        ? const Text("  None", style: TextStyle(fontSize: 13))
                        : Text(
                          // Display managed streams, indicate forwarding status
                          managedStreams
                              .map(
                                (id) =>
                                    "$id${forwardingStreams.contains(id) ? ' (FWD)' : ''}",
                              )
                              .join(', '),
                          style: const TextStyle(fontSize: 13),
                        ),
                    const SizedBox(height: 10),
                    const Divider(),
                    Text(
                      "Logs:",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Expanded(
                      child: Container(
                        color: Colors.grey[850],
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 4.0,
                        ),
                        child: ListView.builder(
                          reverse: true,
                          itemCount: logger.logs.length,
                          itemBuilder: (context, index) {
                            final logEntry = logger.logs[index];
                            Color logColor = Colors.grey[300]!;
                            if (logEntry.contains("Error:") ||
                                logEntry.contains("Failed:") ||
                                logEntry.contains("Exception:")) {
                              logColor = Colors.redAccent[100]!;
                            } else if (logEntry.contains("Warn:")) {
                              logColor = Colors.orangeAccent[100]!;
                            } else if (logEntry.contains("Success") ||
                                logEntry.contains("Connected")) {
                              logColor = Colors.lightGreenAccent[100]!;
                            }
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 1.5,
                              ),
                              child: Text(
                                logEntry,
                                style: TextStyle(fontSize: 11, color: logColor),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}
