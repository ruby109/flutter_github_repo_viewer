import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:github_repo_viewer/ui/app_theme.dart';

void main() {
  group('AppTheme', () {
    test('has a light and a dark theme', () {
      expect(AppTheme.light.brightness, Brightness.light);
      expect(AppTheme.dark.brightness, Brightness.dark);
    });

    test('derives both from the same seed color', () {
      expect(
        AppTheme.light.colorScheme,
        ColorScheme.fromSeed(seedColor: AppTheme.seedColor),
      );
      expect(
        AppTheme.dark.colorScheme,
        ColorScheme.fromSeed(
          seedColor: AppTheme.seedColor,
          brightness: Brightness.dark,
        ),
      );
    });
  });
}
