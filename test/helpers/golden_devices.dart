import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:github_repo_viewer/ui/app_theme.dart';

/// Tag for golden tests. They only run on CI (Linux), because font rendering
/// differs between operating systems; see `.github/workflows/golden.yml`.
const goldenTag = 'golden';

/// A screen size to render golden files at.
///
/// Goldens check layout at each size; they do not emulate the platform's look
/// (tests always render with the Android theme and Roboto).
class GoldenDevice {
  const GoldenDevice(
    this.name, {
    required this.size,
    required this.pixelRatio,
    this.safeArea = EdgeInsets.zero,
  });

  /// Used in golden file names, e.g. `home_shell_search_iphone_se.png`.
  final String name;

  /// Logical screen size.
  final Size size;
  final double pixelRatio;

  /// Approximate system UI insets (status bar, home indicator), in logical
  /// pixels.
  final EdgeInsets safeArea;
}

const goldenDevices = [
  GoldenDevice(
    'iphone_17',
    size: Size(402, 874),
    pixelRatio: 3,
    safeArea: EdgeInsets.only(top: 62, bottom: 34),
  ),
  GoldenDevice(
    'iphone_se',
    size: Size(375, 667),
    pixelRatio: 2,
    safeArea: EdgeInsets.only(top: 20),
  ),
  GoldenDevice(
    'ipad',
    size: Size(820, 1180),
    pixelRatio: 2,
    safeArea: EdgeInsets.only(top: 24, bottom: 20),
  ),
  GoldenDevice(
    'android_phone',
    size: Size(412, 915),
    pixelRatio: 2.625,
    safeArea: EdgeInsets.only(top: 24, bottom: 24),
  ),
];

/// Defines a golden test that renders at [device], in the system's light or
/// dark mode ([brightness]).
///
/// The test is tagged [goldenTag] and draws real shadows; flutter_test
/// otherwise paints elevation as solid black bands. Widgets under test should
/// use the app's themes ([goldenTheme] and [goldenDarkTheme]) so the system
/// brightness picks one, as in the app.
void testGoldens(
  String description,
  GoldenDevice device,
  WidgetTesterCallback callback, {
  Brightness brightness = Brightness.light,
}) {
  final mode = brightness == Brightness.dark ? ' in dark mode' : '';
  testWidgets('$description on ${device.name}$mode', (tester) async {
    _useDevice(tester, device);
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    debugDisableShadows = false;
    try {
      await callback(tester);
    } finally {
      // flutter_test checks this before tear-downs run, so restore it here.
      debugDisableShadows = true;
    }
  }, tags: goldenTag);
}

/// Ends golden file names for dark mode, e.g. `stars_screen_starred_dark_ipad.png`.
String goldenModeSuffix(Brightness brightness) =>
    brightness == Brightness.dark ? '_dark' : '';

/// The app's themes, for `MaterialApp.theme` and `darkTheme` in golden tests.
ThemeData get goldenTheme => AppTheme.light;
ThemeData get goldenDarkTheme => AppTheme.dark;

void _useDevice(WidgetTester tester, GoldenDevice device) {
  final insets = device.safeArea * device.pixelRatio;
  final padding = FakeViewPadding(
    left: insets.left,
    top: insets.top,
    right: insets.right,
    bottom: insets.bottom,
  );
  tester.view
    ..physicalSize = device.size * device.pixelRatio
    ..devicePixelRatio = device.pixelRatio
    ..padding = padding
    ..viewPadding = padding;
  addTearDown(tester.view.reset);
}
