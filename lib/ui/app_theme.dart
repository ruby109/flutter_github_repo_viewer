import 'package:flutter/material.dart';

/// The app's light and dark themes; the system setting picks one.
abstract final class AppTheme {
  /// Both themes derive their colors from it, so they match.
  static const seedColor = Colors.deepPurple;

  static final light = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
  );

  static final dark = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    ),
  );
}
