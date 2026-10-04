import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:github_repo_viewer/data/github/github_repo.dart';
import 'package:github_repo_viewer/data/preferences/shared_preferences_provider.dart';
import 'package:github_repo_viewer/state/search_results_notifier.dart';
import 'package:github_repo_viewer/ui/common/repo_list_tile.dart';
import 'package:github_repo_viewer/ui/common/star_button.dart';
import 'package:github_repo_viewer/ui/search/search_results_list.dart';

import '../../helpers/github_json.dart';
import '../../helpers/preferences.dart';

void main() {
  group('SearchResultsList', () {
    final repos = [
      for (var id = 1; id <= 3; id++)
        GitHubRepo.fromJson(repoJson(id: id, fullName: 'owner/r$id')),
    ];

    Future<void> pumpList(
      WidgetTester tester, {
      ValueChanged<GitHubRepo>? onRepoTap,
    }) async {
      final preferences = await inMemoryPreferences();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
          child: MaterialApp(
            home: Scaffold(
              body: SearchResultsList(
                results: SearchResults(
                  items: repos,
                  totalCount: 3,
                  hasMore: false,
                ),
                onRepoTap: onRepoTap ?? (_) {},
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
  });
}
