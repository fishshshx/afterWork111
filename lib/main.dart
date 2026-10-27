import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/app_database_factory.dart';
import 'data/services/photo_service.dart';
import 'providers/app_database_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initAppDatabase();
  final photoFileService = await PhotoService.getService();
  runApp(
    ProviderScope(
      overrides: [
        photoFileServiceProvider.overrideWithValue(photoFileService),
      ],
      child: const AfterWorkApp(),
    ),
  );
}
