import 'dart:async';

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
