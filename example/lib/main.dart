import 'dart:core';
import 'dart:io';
import 'package:flutter/material.dart';

import 'http_override.dart';
import 'remote_peer_example.dart';

void main() {
  HttpOverrides.global = DeviceHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MaterialApp(home: RemotePeerExample()));
}
