import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'config_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ConfigService(),
      child: const MyApp(),
    ),
  );
}
