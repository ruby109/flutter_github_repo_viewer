import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:github_repo_viewer/data/preferences/shared_preferences_provider.dart';
import 'package:github_repo_viewer/ui/startup/app_startup_widget.dart';

import '../../helpers/golden_devices.dart';
import '../../helpers/preferences.dart';

void main() {
  group('AppStartupWidget', () {
    Future<void> pumpStartup(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: goldenTheme,
            darkTheme: goldenDarkTheme,
            home: const AppStartupWidget(child: Text('app')),
          ),
        ),
      );
    }

    Finder launchBackground([Color color = AppStartupWidget.lightBackground]) =>
        find.byWidgetPredicate(
          (widget) => widget is ColoredBox && widget.color == color,
        );

    // The loading background only hides the load if it continues the native
    // launch screen, in light and dark mode alike.
    group('launch background', () {
      test('is white in light mode and black in dark mode', () {
        expect(AppStartupWidget.lightBackground, const Color(0xFFFFFFFF));
        expect(AppStartupWidget.darkBackground, const Color(0xFF000000));
      });

      // systemBackground is white in light mode and black in dark mode.
      test('matches the iOS launch screen', () {
        final storyboard = File('ios/Runner/Base.lproj/LaunchScreen.storyboard')
            .readAsStringSync();

        expect(
          storyboard,
          contains(
            '<color key="backgroundColor" systemColor="systemBackgroundColor"/>',
          ),
        );
      });

      test('matches the Android launch screen in light and dark mode', () {
        final res = Directory('android/app/src/main/res');
        // The launch drawable takes the theme's background color.
        expect(
          File('${res.path}/drawable-v21/launch_background.xml')
              .readAsStringSync(),
          contains('?android:colorBackground'),
        );

        // Light themes have a white background, black themes a black one.
        Iterable<String?> themeParents(String values) {
          final styles = File('${res.path}/$values/styles.xml');
          return RegExp(
            r'<style name="(?:Launch|Normal)Theme" parent="([^"]+)"',
          ).allMatches(styles.readAsStringSync()).map((m) => m.group(1));
        }

        expect(
          themeParents('values'),
          everyElement('@android:style/Theme.Light.NoTitleBar'),
        );
        expect(
          themeParents('values-night'),
          everyElement('@android:style/Theme.Black.NoTitleBar'),
        );
      });
    });

    testWidgets('shows a plain launch background while loading', (
      tester,
    ) async {
      final (_, store) = await controlledPreferences();
      store.readGate = Completer<void>();

      await pumpStartup(tester);
      await tester.pump();

      expect(launchBackground(), findsOneWidget);
      // A load usually takes milliseconds; a spinner would only flash.
      expect(find.byType(ProgressIndicator), findsNothing);
      expect(find.text('app'), findsNothing);

      store.readGate!.complete();
      await tester.pump();
    });

    testWidgets('shows the dark launch background in dark mode', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final (_, store) = await controlledPreferences();
      store.readGate = Completer<void>();

      await pumpStartup(tester);
      await tester.pump();

      expect(launchBackground(AppStartupWidget.darkBackground), findsOneWidget);

      store.readGate!.complete();
      await tester.pump();
    });

    testWidgets('shows the app once the preferences have loaded', (
      tester,
    ) async {
      await inMemoryPreferences({PreferenceKeys.favorites: '[]'});

      await pumpStartup(tester);
      await tester.pump();

      expect(find.text('app'), findsOneWidget);
      expect(launchBackground(), findsNothing);
      final container = ProviderScope.containerOf(
        tester.element(find.text('app')),
      );
      expect(
        container.read(sharedPreferencesProvider).get(PreferenceKeys.favorites),
        '[]',
      );
    });

    testWidgets('shows an error with Retry when loading fails', (tester) async {
      final (_, store) = await controlledPreferences();
      store.readError = Exception('corrupt file');

      await pumpStartup(tester);
      await tester.pump();

      expect(find.text("Couldn't load your data"), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
      expect(find.text('app'), findsNothing);
    });

    testWidgets('Retry loads again and shows the app', (tester) async {
      final (_, store) = await controlledPreferences();
      store.readError = Exception('corrupt file');
      await pumpStartup(tester);
      await tester.pump();

      store
        ..readError = null
        ..readGate = Completer<void>();
      await tester.tap(find.text('Retry'));
      await tester.pump();

      // While loading again, the plain background replaces the error.
      expect(launchBackground(), findsOneWidget);
      expect(find.text('Retry'), findsNothing);

      store.readGate!.complete();
      await tester.pump();

      expect(find.text('app'), findsOneWidget);
    });

    testWidgets('shows the error again when Retry fails', (tester) async {
      final (_, store) = await controlledPreferences();
      store.readError = Exception('corrupt file');
      await pumpStartup(tester);
      await tester.pump();

      await tester.tap(find.text('Retry'));
      await tester.pump(); // starts loading again
      await tester.pump(); // fails

      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('app'), findsNothing);
    });

    group('golden', () {
      for (final device in goldenDevices) {
        for (final brightness in Brightness.values) {
          testGoldens('error', device, brightness: brightness, (tester) async {
            final (_, store) = await controlledPreferences();
            store.readError = Exception('corrupt file');

            await pumpStartup(tester);
            await tester.pump();

            await expectLater(
              find.byType(AppStartupWidget),
              matchesGoldenFile(
                'goldens/app_startup_widget_error'
                '${goldenModeSuffix(brightness)}_${device.name}.png',
              ),
            );
          });
        }
      }
    });
  });
}
