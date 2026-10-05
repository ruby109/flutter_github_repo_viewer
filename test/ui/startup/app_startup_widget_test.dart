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
        const ProviderScope(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: AppStartupWidget(child: Text('app')),
          ),
        ),
      );
    }

    Finder launchBackground() => find.byWidgetPredicate(
      (widget) =>
          widget is ColoredBox &&
          widget.color == AppStartupWidget.launchBackground,
    );

    // The loading background only hides the load if it continues the native
    // launch screen, in light and dark mode alike.
    group('launchBackground', () {
      test('is white', () {
        expect(AppStartupWidget.launchBackground, const Color(0xFFFFFFFF));
      });

      test('matches the iOS launch screen', () {
        final storyboard = File('ios/Runner/Base.lproj/LaunchScreen.storyboard')
            .readAsStringSync();

        expect(
          storyboard,
          contains(
            '<color key="backgroundColor" red="1" green="1" blue="1" '
            'alpha="1"',
          ),
        );
      });

      test('matches the Android launch screen in light and dark mode', () {
        final res = Directory('android/app/src/main/res');
        // Both drawables are white under a light theme: one names white,
        // the other uses the theme's ?android:colorBackground.
        expect(
          File('${res.path}/drawable/launch_background.xml').readAsStringSync(),
          contains('@android:color/white'),
        );
        expect(
          File('${res.path}/drawable-v21/launch_background.xml')
              .readAsStringSync(),
          contains('?android:colorBackground'),
        );

        // A values-night theme with a dark parent would make the launch
        // screen black in dark mode; the app has no dark theme.
        final styles = [
          for (final dir in res.listSync().whereType<Directory>())
            if (dir.path.split('/').last.startsWith('values'))
              File('${dir.path}/styles.xml'),
        ].where((file) => file.existsSync());
        expect(styles, isNotEmpty);
        for (final file in styles) {
          final parents = RegExp(
            r'<style name="(?:Launch|Normal)Theme" parent="([^"]+)"',
          ).allMatches(file.readAsStringSync()).map((m) => m.group(1));
          expect(
            parents,
            everyElement('@android:style/Theme.Light.NoTitleBar'),
            reason: file.path,
          );
        }
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
        testGoldens('error', device, (tester) async {
          final (_, store) = await controlledPreferences();
          store.readError = Exception('corrupt file');

          await pumpStartup(tester);
          await tester.pump();

          await expectLater(
            find.byType(AppStartupWidget),
            matchesGoldenFile(
              'goldens/app_startup_widget_error_${device.name}.png',
            ),
          );
        });
      }
    });
  });
}
