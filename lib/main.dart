import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'bridge_server.dart';
import 'services/api_service.dart';
import 'services/file_cache_service.dart';
import 'services/settings_service.dart';
import 'state/kiosk_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  await _initPlatformWindowIfNeeded();

  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => SettingsService()),
        Provider(create: (_) => ApiService()),
        Provider(create: (_) => FileCacheService()),
        ChangeNotifierProvider(
          create: (context) {
            final controller = KioskController(
              settingsService: context.read<SettingsService>(),
              apiService: context.read<ApiService>(),
              fileCacheService: context.read<FileCacheService>(),
            );

            startBridge(controller);
            controller.bootstrap();

            return controller;
          },
        ),
      ],
      child: const KioskPlayerApp(),
    ),
  );
}

Future<void> _initPlatformWindowIfNeeded() async {
  if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    return;
  }

  await windowManager.ensureInitialized();

  const options = WindowOptions(
    size: Size(1366, 768),
    center: true,
    backgroundColor: Colors.black,
    titleBarStyle: TitleBarStyle.hidden,
    title: 'Kiosk Player',
  );

  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}