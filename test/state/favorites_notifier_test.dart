import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:github_repo_viewer/data/github/github_repo.dart';
import 'package:github_repo_viewer/data/preferences/shared_preferences_provider.dart';
import 'package:github_repo_viewer/state/favorites_notifier.dart';

import '../helpers/github_json.dart';
import '../helpers/preferences.dart';

void main() {
  group('FavoritesNotifier', () {
    /// A container whose preferences start with [data].
    Future<ProviderContainer> containerWith([
      Map<String, Object> data = const {},
    ]) async {
      final preferences = await inMemoryPreferences(data);
      return ProviderContainer.test(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      );
    }

    Iterable<String> fullNames(List<GitHubRepo> repos) =>
        repos.map((repo) => repo.fullName);

    group('restore', () {
      test('starts empty when nothing is stored', () async {
        final container = await containerWith();

        expect(container.read(favoritesProvider), isEmpty);
      });

      test('restores stored favorites in order', () async {
        final container = await containerWith({
          FavoritesNotifier.storageKey: jsonEncode([
            repoJson(id: 2, fullName: 'b/two'),
            repoJson(id: 1, fullName: 'a/one'),
          ]),
        });

        final favorites = container.read(favoritesProvider);

        expect(fullNames(favorites), ['b/two', 'a/one']);
        expect(
          favorites.first.owner?.avatarUrl,
          'https://avatars.githubusercontent.com/u/2?v=4',
        );
      });
    });
  });
}
