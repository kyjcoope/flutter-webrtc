import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart' as shelf_router;
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../app_logger.dart';
import '../config.dart';
import 'stream_service.dart';
import 'mock_grpc_service.dart';

class ApiService {
  final AppLogger _logger;
  final StreamService _streamService;
  final MockGrpcService _mockGrpcService;
  HttpServer? _server;
  bool _isRunning = false;
  String? _error;
  InternetAddress? get address => _server?.address;
  int? get port => _server?.port;
  bool get isRunning => _isRunning;
  String? get error => _error;

  ApiService(this._logger, this._streamService, this._mockGrpcService);

  Future<void> start() async {
    if (_isRunning) {
      _logger.addLog("API Service already running.");
      return;
    }
    _logger.addLog("Starting API Service...");
    _error = null;

    final router = _createRouter();
    final handler = _createPipeline(router.call);

    try {
      _server = await shelf_io.serve(handler, dartApiHost, dartApiPort);
      _isRunning = true;
      _logger.addLog(
        'API Service started on http://${_server!.address.host}:${_server!.port}',
      );
    } catch (e, s) {
      _error = e.toString();
      _isRunning = false;
      _logger.addLog('Error starting API server: $e\nStack: $s');
      _server = null;
      rethrow;
    }
  }

  Future<void> stop() async {
    if (!_isRunning || _server == null) {
      _logger.addLog("API Service is not running or already stopped.");
      return;
    }
    _logger.addLog("Stopping API Service...");
    try {
      await _server!.close(force: true);
      _logger.addLog("API Service stopped successfully.");
    } catch (e) {
      _logger.addLog("Error stopping API Service: $e");
      _error = "Error during stop: $e";
    } finally {
      _isRunning = false;
      _server = null;
    }
  }

  shelf_router.Router _createRouter() {
    final router = shelf_router.Router();

    router.get('/streams', (shelf.Request request) async {
      final streamIds = await _mockGrpcService.getCameraList();
      _logger.addLog(
        "API Request: GET /streams -> Responding with available streams: $streamIds",
      );
      return shelf.Response.ok(
        jsonEncode({'streams': streamIds}),
        headers: {'Content-Type': 'application/json'},
      );
    });

    router.post('/connect/<streamId>', (
      shelf.Request request,
      String streamId,
    ) async {
      _logger.addLog("API Request: POST /connect/$streamId");
      if (!_streamService.isStreamAvailable(streamId)) {
        _logger.addLog(
          "Error: Stream '$streamId' is not available or not known.",
        );
        return shelf.Response.notFound(
          jsonEncode({'error': "Stream '$streamId' not available"}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      String requestBody;
      try {
        requestBody = await request.readAsString();
        if (requestBody.isEmpty) throw FormatException("Request body empty");
      } catch (e) {
        _logger.addLog("Error reading /connect/$streamId body: $e");
        return shelf.Response.badRequest(
          body: jsonEncode({'error': 'Could not read request body: $e'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      RTCSessionDescription clientOffer;
      try {
        final offerMap = jsonDecode(requestBody);
        if (offerMap['sdp'] == null || offerMap['type'] != 'offer') {
          throw FormatException("Invalid offer format");
        }
        clientOffer = RTCSessionDescription(offerMap['sdp'], offerMap['type']);
        _logger.addLog(
          "'$streamId': Received valid OFFER from client via API.",
        );
      } catch (e) {
        _logger.addLog(
          "Error decoding client Offer JSON for /connect/$streamId: $e",
        );
        return shelf.Response.badRequest(
          body: jsonEncode({'error': 'Invalid Offer JSON format: $e'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      try {
        final answer = await _streamService.negotiateAndActivateStream(
          streamId,
          clientOffer,
        );
        if (answer != null) {
          _logger.addLog(
            "'$streamId': Negotiation OK. Sending Answer via API.",
          );
          return shelf.Response.ok(
            jsonEncode(answer.toMap()),
            headers: {'Content-Type': 'application/json'},
          );
        } else {
          _logger.addLog(
            "Error: Failed negotiation via Python for '$streamId'.",
          );
          return shelf.Response.internalServerError(
            body: jsonEncode({
              'error': "Failed WebRTC negotiation with backend",
            }),
            headers: {'Content-Type': 'application/json'},
          );
        }
      } catch (e, s) {
        _logger.addLog("Error processing /connect/$streamId: $e\nStack: $s");
        return shelf.Response.internalServerError(
          body: jsonEncode({
            'error': 'Connection setup error: ${e.toString()}',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    return router;
  }

  shelf.Handler _createPipeline(shelf.Handler router) {
    final corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers':
          'Origin, Content-Type, X-Requested-With, Accept',
    };

    return const shelf.Pipeline()
        .addMiddleware(
          shelf.logRequests(
            logger:
                (msg, isError) =>
                    isError
                        ? _logger.addLog("API Error: $msg")
                        : _logger.addLog("API Access: $msg"),
          ),
        )
        .addMiddleware((innerHandler) {
          return (request) async {
            if (request.method == 'OPTIONS') {
              return shelf.Response.ok(null, headers: corsHeaders);
            }
            final response = await innerHandler(request);
            final combinedHeaders = {...response.headersAll, ...corsHeaders};
            return response.change(headers: combinedHeaders);
          };
        })
        .addHandler(router);
  }
}
