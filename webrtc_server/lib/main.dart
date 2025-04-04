import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'app_logger.dart';
import 'services/mock_grpc_service.dart';
import 'services/stream_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppLogger()),
        Provider(
          create: (context) => MockGrpcService(context.read<AppLogger>()),
        ),
        ChangeNotifierProvider(
          create:
              (context) => StreamService(
                context.read<AppLogger>(),
                context.read<MockGrpcService>(),
              ),
        ),
      ],
      child: const MyApp(),
    ),
  );
}
