import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../config_service.dart';
import 'camera_control_widget.dart';
import 'login_page.dart';

class CameraListPage extends StatefulWidget {
  const CameraListPage({super.key});

  @override
  State<CameraListPage> createState() => _CameraListPageState();
}

class _CameraListPageState extends State<CameraListPage> {
  List<String> _streamIds = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Fetch streams immediately when the page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Ensure context is available
        _fetchStreams();
      }
    });
  }

  Future<void> _fetchStreams() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final config = context.read<ConfigService>();
    final url = Uri.parse('${config.apiBaseUrl}/streams');
    print('CameraListPage: Fetching streams from ${url.toString()}');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> streams = data['streams'] ?? [];
        print('CameraListPage: Received streams: $streams');
        setState(() {
          _streamIds = streams.map((e) => e.toString()).toList();
          if (_streamIds.isEmpty) {
            _errorMessage = 'No streams available from backend.';
          }
        });
      } else {
        print(
            'CameraListPage: Error fetching streams: ${response.statusCode} ${response.reasonPhrase}');
        setState(() {
          _errorMessage = 'Error fetching streams: ${response.statusCode}';
          _streamIds = [];
        });
      }
    } catch (e) {
      print('CameraListPage: Failed to fetch streams: $e');
      if (mounted) {
        setState(() {
          _errorMessage =
              'Failed to connect to backend at ${config.backendHost}.';
          _streamIds = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _logout() {
    // Navigate back to login page
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = context.read<ConfigService>(); // Get config for display

    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Cameras'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh List',
            onPressed: _isLoading ? null : _fetchStreams,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Change Backend Address',
            onPressed: _logout,
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text('Backend: ${config.apiBaseUrl}',
                style: Theme.of(context).textTheme.bodySmall),
          ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_errorMessage != null)
            Expanded(
                child: Center(
                    child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(_errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center),
            )))
          else if (_streamIds.isEmpty)
            const Expanded(
                child:
                    Center(child: Text('No available camera streams found.')))
          else
            Expanded(
              child: ListView.builder(
                itemCount: _streamIds.length,
                itemBuilder: (context, index) {
                  final streamId = _streamIds[index];
                  // Each camera gets its own control widget
                  return CameraControlWidget(
                      key: ValueKey(
                          streamId), // Important for state preservation if list changes
                      streamId: streamId);
                },
              ),
            ),
        ],
      ),
    );
  }
}
