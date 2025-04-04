import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppLogger extends ChangeNotifier {
  final List<String> _logs = [];
  final int maxLogs = 150;
  List<String> get logs => List.unmodifiable(_logs);
  bool _isUiActive = true;

  void setUiActive(bool active) {
    _isUiActive = active;
  }

  void addLog(String message) {
    final timestamp = DateFormat('HH:mm:ss.SSS').format(DateTime.now());
    final logEntry = "[$timestamp] $message";
    print(logEntry);

    if (_isUiActive && ChangeNotifier.debugAssertNotDisposed(this)) {
      _logs.insert(0, logEntry);
      if (_logs.length > maxLogs) {
        _logs.removeLast();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isUiActive && ChangeNotifier.debugAssertNotDisposed(this)) {
          notifyListeners();
        }
      });
    }
  }

  void clearLogs() {
    if (_isUiActive && ChangeNotifier.debugAssertNotDisposed(this)) {
      _logs.clear();
      notifyListeners();
    }
  }
}
