import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'ui/shell/home_shell.dart';
import 'ui/startup/app_startup_widget.dart';

void main() {
  // Runs the app at once: AppStartupWidget loads the preferences, so a failed
  // load shows an error with Retry instead of leaving the native launch
  // screen up forever.
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GitHub Repo Viewer',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      // Inside MaterialApp, so the startup error uses the app's theme.
      home: const AppStartupWidget(child: HomeShell()),
    );
  }
}
