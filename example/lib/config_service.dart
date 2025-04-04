import 'package:flutter/foundation.dart';
import '../config.dart';

class ConfigService extends ChangeNotifier {
  String _backendHost = defaultBackendHost;
  int _backendPort = defaultBackendApiPort;

  String get backendHost => _backendHost;
  int get backendPort => _backendPort;

  String get apiBaseUrl => 'http://$_backendHost:$_backendPort';

  void updateBackendAddress(String host, {int? port}) {
    final newHost = host.trim();
    final newPort = port ?? _backendPort;
    if (newHost.isNotEmpty && newPort > 0 && newPort < 65536) {
      if (_backendHost != newHost || _backendPort != newPort) {
        _backendHost = newHost;
        _backendPort = newPort;
        print('ConfigService: Backend address updated to $apiBaseUrl');
        notifyListeners();
      }
    } else {
      print('ConfigService: Warn: Invalid host or port provided for update.');
    }
  }
}
