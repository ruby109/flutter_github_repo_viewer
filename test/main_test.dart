import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:github_repo_viewer/main.dart' as app;
import 'package:github_repo_viewer/data/preferences/shared_preferences_provider.dart';
import 'package:github_repo_viewer/main.dart';
import 'package:github_repo_viewer/state/favorites_notifier.dart';
import 'package:github_repo_viewer/ui/shell/home_shell.dart';

import 'helpers/github_json.dart';
import 'helpers/preferences.dart';

void main() {
  group('main', () {
    testWidgets('loads stored favorites before showing the app', (
      tester,
    ) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
            FavoritesNotifier.storageKey: jsonEncode([
              repoJson(id: 1, fullName: 'a/one'),
            ]),
          });

      await app.main();
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
    testWidgets('opens on the home shell', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(
              await inMemoryPreferences(),
            ),
          ],
          child: const MyApp(),
        ),
      );

      expect(find.byType(HomeShell), findsOneWidget);
    });
  });
}
