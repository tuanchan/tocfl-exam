import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'core/app_theme.dart';
import 'pages/app_shell.dart';
import 'services/highlight_store.dart';
import 'services/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  pdfrxFlutterInitialize();
  final settings = SettingsStore();
  await Future.wait([settings.load(), HighlightStore.instance.load()]);
  runApp(TocflApp(settings: settings));
}

class TocflApp extends StatelessWidget {
  const TocflApp({super.key, required this.settings});

  final SettingsStore settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: 'TOCFL Full Exam',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
        home: AppShell(settings: settings),
      ),
    );
  }
}
