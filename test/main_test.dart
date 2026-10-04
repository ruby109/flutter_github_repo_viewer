import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:github_repo_viewer/main.dart' as app;
import 'package:github_repo_viewer/main.dart';
import 'package:github_repo_viewer/state/favorites_notifier.dart';
import 'package:github_repo_viewer/ui/shell/home_shell.dart';
import 'package:github_repo_viewer/ui/startup/app_startup_widget.dart';

import 'helpers/github_json.dart';
import 'helpers/preferences.dart';

void main() {
  group('main', () {
    testWidgets('shows the app without waiting for the preferences', (
      tester,
    ) async {
      final (_, store) = await controlledPreferences();
      store.readGate = Completer<void>();

      app.main();
      await tester.pump();

      expect(find.byType(AppStartupWidget), findsOneWidget);
      expect(find.byType(HomeShell), findsNothing);

      store.readGate!.complete();
      await tester.pump(); // finishes loading
      await tester.pump(); // shows the app

      expect(find.byType(HomeShell), findsOneWidget);
    });

    testWidgets('loads stored favorites before showing the app', (
      tester,
    ) async {
      await inMemoryPreferences({
        FavoritesNotifier.storageKey: jsonEncode([
          repoJson(id: 1, fullName: 'a/one'),
        ]),
      });

      app.main();
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeShell)),
      );
      expect(container.read(favoritesProvider).map((repo) => repo.fullName), [
        'a/one',
      ]);
    });
  });

  group('MyApp', () {
    testWidgets('opens on the home shell once the preferences load', (
      tester,
    ) async {
      await inMemoryPreferences();

      await tester.pumpWidget(const ProviderScope(child: MyApp()));
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(AppStartupWidget),
          matching: find.byType(HomeShell),
        ),
        findsOneWidget,
      );
    });
  });
}
