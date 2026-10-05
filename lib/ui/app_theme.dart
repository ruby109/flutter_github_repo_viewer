import 'package:flutter/material.dart';

/// The app's light and dark themes; the system setting picks one.
abstract final class AppTheme {
  /// Both themes derive their colors from it, so they match.
  static const seedColor = Colors.deepPurple;

  // Getters, not fields: ThemeData takes the current platform when it is
  // built, and platform-adaptive widgets (e.g. the loading indicator) read it.
  static ThemeData get light =>
      ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: seedColor));

  static ThemeData get dark => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    ),
  );
}
