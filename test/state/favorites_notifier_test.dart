import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:github_repo_viewer/data/github/github_repo.dart';
import 'package:github_repo_viewer/data/preferences/shared_preferences_provider.dart';
import 'package:github_repo_viewer/state/favorites_notifier.dart';

import '../helpers/github_json.dart';
import '../helpers/preferences.dart';

void main() {
  ProviderContainer containerFor(SharedPreferencesWithCache preferences) {
    return ProviderContainer.test(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
  }

  group('FavoritesNotifier', () {
    /// A container whose preferences start with [data].
    Future<ProviderContainer> containerWith([
      Map<String, Object> data = const {},
    ]) async {
      return containerFor(await inMemoryPreferences(data));
    }

    /// A container over the same stored data, as after an app restart.
    Future<ProviderContainer> restart() async {
      return containerFor(await reopenPreferences());
    }

    GitHubRepo repo(int id) =>
        GitHubRepo.fromJson(repoJson(id: id, fullName: 'owner/r$id'));

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

    group('toggle', () {
      test('stars a repository, most recent first', () async {
        final container = await containerWith();
        final notifier = container.read(favoritesProvider.notifier);

        await notifier.toggle(repo(1));
        await notifier.toggle(repo(2));

        expect(fullNames(container.read(favoritesProvider)), [
          'owner/r2',
          'owner/r1',
        ]);
      });

      test('unstars a starred repository', () async {
        final container = await containerWith();
        final notifier = container.read(favoritesProvider.notifier);
        await notifier.toggle(repo(1));
        await notifier.toggle(repo(2));

        await notifier.toggle(repo(1));

        expect(fullNames(container.read(favoritesProvider)), ['owner/r2']);
      });

      // The detail screen stars its own GitHubRepo instance, built from a
      // different response than the search list's.
      test('matches repositories by id', () async {
        final container = await containerWith();
        final notifier = container.read(favoritesProvider.notifier);
        await notifier.toggle(repo(1));

        await notifier.toggle(
          const GitHubRepo(id: 1, fullName: 'owner/renamed', owner: null),
        );

        expect(container.read(favoritesProvider), isEmpty);
      });

      test('updates state before saving finishes', () async {
        final container = await containerWith();

        final saving = container
            .read(favoritesProvider.notifier)
            .toggle(repo(1));

        expect(fullNames(container.read(favoritesProvider)), ['owner/r1']);
        await saving;
      });

      test('persists stars across restarts', () async {
        final container = await containerWith();
        final notifier = container.read(favoritesProvider.notifier);
        await notifier.toggle(repo(1));
        await notifier.toggle(repo(2));

        final restarted = await restart();

        final favorites = restarted.read(favoritesProvider);
        expect(fullNames(favorites), ['owner/r2', 'owner/r1']);
        expect(favorites.first.owner?.avatarUrl, repo(2).owner?.avatarUrl);
      });

      test('persists unstars across restarts', () async {
        final container = await containerWith();
        final notifier = container.read(favoritesProvider.notifier);
        await notifier.toggle(repo(1));
        await notifier.toggle(repo(1));

        final restarted = await restart();

        expect(restarted.read(favoritesProvider), isEmpty);
      });
    });
  });
}
