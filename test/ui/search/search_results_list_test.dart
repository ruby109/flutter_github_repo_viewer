import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:github_repo_viewer/data/github/github_api_exception.dart';
import 'package:github_repo_viewer/data/github/github_repo.dart';
import 'package:github_repo_viewer/data/github/search_page.dart';
import 'package:github_repo_viewer/data/preferences/shared_preferences_provider.dart';
import 'package:github_repo_viewer/state/search_results_notifier.dart';
import 'package:github_repo_viewer/ui/common/repo_list_tile.dart';
import 'package:github_repo_viewer/ui/common/star_button.dart';
import 'package:github_repo_viewer/ui/search/search_results_list.dart';

import '../../helpers/avatars.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/github_json.dart';
import '../../helpers/golden_devices.dart';
import '../../helpers/preferences.dart';

void main() {
  group('SearchResultsList', () {
    List<GitHubRepo> reposUpTo(int count) => [
      for (var id = 1; id <= count; id++)
        GitHubRepo.fromJson(repoJson(id: id, fullName: 'owner/r$id')),
    ];

    final repos = reposUpTo(3);

    Future<void> pumpList(
      WidgetTester tester, {
      SearchResults? results,
      ValueChanged<GitHubRepo>? onRepoTap,
      VoidCallback? onLoadMore,
      VoidCallback? onRetryLoadMore,
    }) async {
      final preferences = await inMemoryPreferences();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: SearchResultsList(
                results:
                    results ??
                    SearchResults(items: repos, totalCount: 3, hasMore: false),
                onRepoTap: onRepoTap ?? (_) {},
                onLoadMore: onLoadMore ?? () {},
                onRetryLoadMore: onRetryLoadMore ?? () {},
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('shows a row with a star button for each result', (
      tester,
    ) async {
      await pumpList(tester);

      expect(find.byType(RepoListTile), findsNWidgets(3));
      for (final repo in repos) {
        expect(
          find.widgetWithText(RepoListTile, repo.fullName),
          findsOneWidget,
        );
      }
      expect(
        tester
            .widgetList<StarButton>(find.byType(StarButton))
            .map((button) => button.repo.id),
        [1, 2, 3],
      );
    });

    testWidgets('opens a repository when its row is tapped', (tester) async {
      final tapped = <GitHubRepo>[];
      await pumpList(tester, onRepoTap: tapped.add);

      await tester.tap(find.text('owner/r2'));

      expect(tapped.single.id, 2);
    });

    testWidgets('hides the keyboard when scrolled', (tester) async {
      await pumpList(tester);

      final list = tester.widget<ListView>(find.byType(ListView));
      expect(
        list.keyboardDismissBehavior,
        ScrollViewKeyboardDismissBehavior.onDrag,
      );
    });

    group('loading more', () {
      /// 60 rows: more than fit on the 800 pixel high test screen.
      final manyRepos = reposUpTo(60);

      testWidgets('asks for more when the last rows are shown', (tester) async {
        var loads = 0;
        await pumpList(
          tester,
          results: SearchResults(
            items: manyRepos,
            totalCount: 90,
            hasMore: true,
          ),
          onLoadMore: () => loads++,
        );
        await tester.pump();

        expect(loads, 0);

        await tester.scrollUntilVisible(find.text('owner/r55'), 500);
        await tester.pump();

        expect(loads, greaterThan(0));
      });

      // A first page that doesn't fill the screen can't be scrolled.
      testWidgets('asks for more when every row fits on screen', (
        tester,
      ) async {
        var loads = 0;
        await pumpList(
          tester,
          results: SearchResults(items: repos, totalCount: 90, hasMore: true),
          onLoadMore: () => loads++,
        );
        await tester.pump();

        expect(loads, greaterThan(0));
      });

      testWidgets('does not ask for more when there is none', (tester) async {
        var loads = 0;
        await pumpList(tester, onLoadMore: () => loads++);
        await tester.pump();

        expect(loads, 0);
      });

      // Rows keep being built while scrolling; only the user retries.
      testWidgets('does not ask for more after loading failed', (tester) async {
        var loads = 0;
        await pumpList(
          tester,
          results: SearchResults(
            items: repos,
            totalCount: 90,
            hasMore: true,
            loadMoreError: const NetworkException('offline'),
          ),
          onLoadMore: () => loads++,
        );
        await tester.pump();

        expect(loads, 0);
      });
    });

    group('end of the list', () {
      final spinner = find.byType(CircularProgressIndicator);

      testWidgets('shows a loading indicator while more can load', (
        tester,
      ) async {
        await pumpList(
          tester,
          results: SearchResults(items: repos, totalCount: 90, hasMore: true),
        );

        expect(spinner, findsOneWidget);
      });

      testWidgets('shows why loading more failed, with a retry button', (
        tester,
      ) async {
        var retries = 0;
        await pumpList(
          tester,
          results: SearchResults(
            items: repos,
            totalCount: 90,
            hasMore: true,
            loadMoreError: const NetworkException('offline'),
          ),
          onRetryLoadMore: () => retries++,
        );

        expect(
          find.textContaining('Check your internet connection'),
          findsOneWidget,
        );
        expect(spinner, findsNothing);

        await tester.tap(find.text('Retry'));

        expect(retries, 1);
      });

      testWidgets('says only the first 1,000 results are shown', (
        tester,
      ) async {
        await pumpList(
          tester,
          results: SearchResults(
            items: repos,
            totalCount: 5000,
            hasMore: false,
          ),
        );

        expect(find.text(SearchResultsList.searchLimitMessage), findsOneWidget);
      });

      testWidgets('shows nothing once every result is loaded', (tester) async {
        await pumpList(tester);

        expect(spinner, findsNothing);
        expect(find.text(SearchResultsList.searchLimitMessage), findsNothing);
        expect(find.text('Retry'), findsNothing);
      });
    });

    group('golden', () {
      for (final device in goldenDevices) {
        testGoldens('search limit reached', device, (tester) async {
          final fixture = SearchPage.fromJson(
            searchFixture(),
            page: 1,
            perPage: 10,
          );

          await withAvatarFixtures((_) async {
            await pumpList(
              tester,
              results: SearchResults(
                items: fixture.items,
                totalCount: fixture.totalCount,
                hasMore: false,
              ),
            );
            await tester.drag(find.byType(ListView), const Offset(0, -2000));
            await tester.pumpAndSettle();
            await loadImages(tester);

            await expectLater(
              find.byType(SearchResultsList),
              matchesGoldenFile(
                'goldens/search_results_list_search_limit_${device.name}.png',
              ),
            );
          });
        });
      }
    });
  });
}
