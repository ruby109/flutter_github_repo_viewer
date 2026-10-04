import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:github_repo_viewer/data/github/github_repo.dart';
import 'package:github_repo_viewer/data/preferences/shared_preferences_provider.dart';
import 'package:github_repo_viewer/state/favorites_notifier.dart';
import 'package:github_repo_viewer/ui/common/repo_list_tile.dart';
import 'package:github_repo_viewer/ui/stars/stars_screen.dart';

import '../../helpers/avatars.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/github_json.dart';
import '../../helpers/golden_devices.dart';
import '../../helpers/preferences.dart';

void main() {
  group('StarsScreen', () {
    GitHubRepo repoWithId(int id) =>
        GitHubRepo.fromJson(repoJson(id: id, fullName: 'owner/r$id'));

    /// Shows the screen over favorites stored as [stored], most recent
    /// first.
    Future<ProviderContainer> pumpScreen(
      WidgetTester tester, {
      List<GitHubRepo> stored = const [],
      ValueChanged<GitHubRepo>? onRepoTap,
    }) async {
      final container = ProviderContainer.test(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await inMemoryPreferences({
              FavoritesNotifier.storageKey: jsonEncode(stored),
            }),
          ),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: StarsScreen(onRepoTap: onRepoTap ?? (_) {})),
        ),
      );
      return container;
    }

    Iterable<String> shownNames(WidgetTester tester) => tester
        .widgetList<RepoListTile>(find.byType(RepoListTile))
        .map((tile) => tile.repo.fullName);

    testWidgets('lists the starred repositories, most recent first', (
      tester,
    ) async {
      await pumpScreen(tester, stored: [repoWithId(2), repoWithId(1)]);

      expect(shownNames(tester), ['owner/r2', 'owner/r1']);
      expect(find.byTooltip('Unstar'), findsNWidgets(2));
    });

    testWidgets('says when nothing is starred', (tester) async {
      await pumpScreen(tester);

      expect(find.text(StarsScreen.emptyTitle), findsOneWidget);
      expect(find.byType(RepoListTile), findsNothing);
    });

    testWidgets('removes a repository when its star is tapped', (tester) async {
      final container = await pumpScreen(
        tester,
        stored: [repoWithId(2), repoWithId(1)],
      );

      await tester.tap(
        find.descendant(
          of: find.widgetWithText(RepoListTile, 'owner/r2'),
          matching: find.byTooltip('Unstar'),
        ),
      );
      await tester.pump();

      expect(shownNames(tester), ['owner/r1']);
      final stored = container
          .read(sharedPreferencesProvider)
          .getString(FavoritesNotifier.storageKey);
      expect(
        (jsonDecode(stored!) as List<Object?>).map(
          (repo) => (repo! as Map<String, Object?>)['full_name'],
        ),
        ['owner/r1'],
      );
    });

    testWidgets('shows the empty state once the last star is removed', (
      tester,
    ) async {
      await pumpScreen(tester, stored: [repoWithId(1)]);

      await tester.tap(find.byTooltip('Unstar'));
      await tester.pump();

      expect(find.text(StarsScreen.emptyTitle), findsOneWidget);
    });

    testWidgets('follows stars changed on other screens', (tester) async {
      final container = await pumpScreen(tester, stored: [repoWithId(1)]);

      await container.read(favoritesProvider.notifier).toggle(repoWithId(3));
      await tester.pump();

      expect(shownNames(tester), ['owner/r3', 'owner/r1']);
    });

    testWidgets('opens a repository when its row is tapped', (tester) async {
      final tapped = <GitHubRepo>[];
      await pumpScreen(tester, stored: [repoWithId(1)], onRepoTap: tapped.add);

      await tester.tap(find.text('owner/r1'));

      expect(tapped.single.id, 1);
    });

    group('golden', () {
      for (final device in goldenDevices) {
        testGoldens('starred', device, (tester) async {
          // Real search results, starred.
          final starred = (searchFixture()['items']! as List<Object?>)
              .take(6)
              .cast<Map<String, Object?>>()
              .map(GitHubRepo.fromJson)
              .toList();

          await withAvatarFixtures((_) async {
            await pumpScreen(tester, stored: starred);
            await loadImages(tester);

            await expectLater(
              find.byType(StarsScreen),
              matchesGoldenFile(
                'goldens/stars_screen_starred_${device.name}.png',
              ),
            );
          });
        });

        testGoldens('empty', device, (tester) async {
          await pumpScreen(tester);

          await expectLater(
            find.byType(StarsScreen),
            matchesGoldenFile('goldens/stars_screen_empty_${device.name}.png'),
          );
        });
      }
    });
  });
}
