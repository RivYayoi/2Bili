import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/legacy.dart';

import 'core/auth_controller.dart';
import 'core/auth_store.dart';
import 'core/bili_api.dart';
import 'core/settings_store.dart';
import 'ui/home_page.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(1100, 720),
      minimumSize: Size(800, 600),
      center: true,
      title: '2bili',
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );
    windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  final authStore = AuthStore();
  final settings = SettingsStore();
  final api = BiliApi(auth: authStore);
  final auth = AuthController(api: api, store: authStore);

  await settings.load();

  runApp(
    MultiProvider(
      providers: [
        Provider<BiliApi>.value(value: api),
        ChangeNotifierProvider<SettingsStore>.value(value: settings),
        ChangeNotifierProvider<AuthController>.value(value: auth),
      ],
      child: const BiliApp(),
    ),
  );

  unawaited(auth.initialize());
}

class BiliApp extends StatelessWidget {
  const BiliApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    return MaterialApp(
      title: '2bili',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: switch (settings.themeMode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      },
      home: const HomePage(),
    );
  }
}
