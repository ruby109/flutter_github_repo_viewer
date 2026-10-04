import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:github_repo_viewer/data/github/github_repo.dart';
import 'package:github_repo_viewer/data/preferences/shared_preferences_provider.dart';
import 'package:github_repo_viewer/state/favorites_notifier.dart';
import 'package:github_repo_viewer/ui/common/star_button.dart';

import '../../helpers/github_json.dart';
import '../../helpers/preferences.dart';

void main() {
  group('StarButton', () {
    final repo = GitHubRepo.fromJson(repoJson(id: 1, fullName: 'a/one'));

    Future<ProviderContainer> pumpButton(
      WidgetTester tester,
      SharedPreferencesWithCache preferences,
    ) async {
      final container = ProviderContainer.test(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Center(child: StarButton(repo: repo)),
            ),
          ),
        ),
      );
      return container;
    }

    Iterable<int> starredIds(ProviderContainer container) =>
        container.read(favoritesProvider).map((repo) => repo.id);

    final starAction = find.byTooltip('Star');
    final unstarAction = find.byTooltip('Unstar');

    testWidgets('offers to star a repository that is not starred', (
      tester,
    ) async {
      await pumpButton(tester, await inMemoryPreferences());

      expect(starAction, findsOneWidget);
      expect(find.byIcon(Icons.star_border), findsOneWidget);
    });

    testWidgets('shows a filled star for a starred repository', (tester) async {
      await pumpButton(
        tester,
        await inMemoryPreferences({
          FavoritesNotifier.storageKey: jsonEncode([repo]),
        }),
      );

      expect(unstarAction, findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('stars and unstars the repository when tapped', (tester) async {
      final container = await pumpButton(tester, await inMemoryPreferences());

      await tester.tap(starAction);
      await tester.pump();

      expect(starredIds(container), [1]);
      expect(unstarAction, findsOneWidget);

      await tester.tap(unstarAction);
      await tester.pump();

      expect(starredIds(container), isEmpty);
      expect(starAction, findsOneWidget);
    });

    testWidgets('follows stars changed elsewhere', (tester) async {
      final container = await pumpButton(tester, await inMemoryPreferences());

      await container.read(favoritesProvider.notifier).toggle(repo);
      await tester.pump();

      expect(unstarAction, findsOneWidget);
    });

    testWidgets('tells the user when the star cannot be saved', (tester) async {
      final (preferences, store) = await controlledPreferences();
      await pumpButton(tester, preferences);

      await tester.tap(starAction);
      await tester.runAsync(() => store.failWrite(0));
      await tester.pump();

      expect(find.text(StarButton.saveFailedMessage), findsOneWidget);
      // The notifier shows what is stored again: nothing.
      expect(starAction, findsOneWidget);
    });
  });
}
