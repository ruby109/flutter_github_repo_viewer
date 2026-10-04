import 'dart:async';
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

  GitHubRepo repoWithId(int id) =>
      GitHubRepo.fromJson(repoJson(id: id, fullName: 'owner/r$id'));

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

      // Stored data can be corrupted or written by an older or newer app
      // version; losing favorites beats crashing on launch.
      group('starts empty when the stored value', () {
        final unusableValues = <String, Object>{
          'is not JSON': '[{"id": 1',
          'is a JSON object': jsonEncode(repoJson()),
          'is a JSON string': jsonEncode('owner/repo'),
          'is not a string': 42,
        };

        unusableValues.forEach((description, value) {
          test(description, () async {
            final container = await containerWith({
              FavoritesNotifier.storageKey: value,
            });

            expect(container.read(favoritesProvider), isEmpty);
          });
        });
      });

      test('skips invalid entries and keeps valid ones', () async {
        final container = await containerWith({
          FavoritesNotifier.storageKey: jsonEncode([
            repoJson(id: 1, fullName: 'a/one'),
            repoJson(id: 2)..remove('full_name'),
            repoJson(id: 3)..['id'] = '3',
            42,
            null,
            repoJson(id: 4, fullName: 'd/four'),
          ]),
        });

        expect(fullNames(container.read(favoritesProvider)), [
          'a/one',
          'd/four',
        ]);
      });

      test('drops duplicate ids, keeping the first', () async {
        final container = await containerWith({
          FavoritesNotifier.storageKey: jsonEncode([
            repoJson(id: 1, fullName: 'a/new'),
            repoJson(id: 1, fullName: 'a/old'),
          ]),
        });

        expect(fullNames(container.read(favoritesProvider)), ['a/new']);
      });

      test('replaces unusable data on the next star', () async {
        final container = await containerWith({
          FavoritesNotifier.storageKey: 'not json',
        });

        await container.read(favoritesProvider.notifier).toggle(repoWithId(1));
        final restarted = await restart();

        expect(fullNames(restarted.read(favoritesProvider)), ['owner/r1']);
      });
    });

    group('toggle', () {
      test('stars a repository, most recent first', () async {
        final container = await containerWith();
        final notifier = container.read(favoritesProvider.notifier);

        await notifier.toggle(repoWithId(1));
        await notifier.toggle(repoWithId(2));

        expect(fullNames(container.read(favoritesProvider)), [
          'owner/r2',
          'owner/r1',
        ]);
      });

      test('unstars a starred repository', () async {
        final container = await containerWith();
        final notifier = container.read(favoritesProvider.notifier);
        await notifier.toggle(repoWithId(1));
        await notifier.toggle(repoWithId(2));

        await notifier.toggle(repoWithId(1));

        expect(fullNames(container.read(favoritesProvider)), ['owner/r2']);
      });

      // The detail screen stars its own GitHubRepo instance, built from a
      // different response than the search list's.
      test('matches repositories by id', () async {
        final container = await containerWith();
        final notifier = container.read(favoritesProvider.notifier);
        await notifier.toggle(repoWithId(1));

        await notifier.toggle(
          const GitHubRepo(id: 1, fullName: 'owner/renamed', owner: null),
        );

        expect(container.read(favoritesProvider), isEmpty);
      });

      test('updates state before saving finishes', () async {
        final container = await containerWith();

        final saving = container
            .read(favoritesProvider.notifier)
            .toggle(repoWithId(1));

        expect(fullNames(container.read(favoritesProvider)), ['owner/r1']);
        await saving;
      });

      test('persists stars across restarts', () async {
        final container = await containerWith();
        final notifier = container.read(favoritesProvider.notifier);
        await notifier.toggle(repoWithId(1));
        await notifier.toggle(repoWithId(2));

        final restarted = await restart();

        final favorites = restarted.read(favoritesProvider);
        expect(fullNames(favorites), ['owner/r2', 'owner/r1']);
        expect(
          favorites.first.owner?.avatarUrl,
          repoWithId(2).owner?.avatarUrl,
        );
      });

      test('persists unstars across restarts', () async {
        final container = await containerWith();
        final notifier = container.read(favoritesProvider.notifier);
        await notifier.toggle(repoWithId(1));
        await notifier.toggle(repoWithId(1));

        final restarted = await restart();

        expect(restarted.read(favoritesProvider), isEmpty);
      });
    });

    // Saves write the whole list, so a later successful save also stores an
    // earlier failed change. After a failure the notifier therefore reloads
    // what is actually stored, once no other save is pending.
    group('when saving fails', () {
      Future<(ProviderContainer, ControlledPreferencesStore)> controlled([
        Map<String, Object> data = const {},
      ]) async {
        final (preferences, store) = await controlledPreferences(data);
        return (containerFor(preferences), store);
      }

      final stored = {
        FavoritesNotifier.storageKey: jsonEncode([repoWithId(1).toJson()]),
      };

      test('throws and restores the stored favorites', () async {
        final (container, store) = await controlled(stored);

        final saving = container
            .read(favoritesProvider.notifier)
            .toggle(repoWithId(2));
        expect(fullNames(container.read(favoritesProvider)), [
          'owner/r2',
          'owner/r1',
        ]);
        store.failWrite(0);

        await expectLater(saving, throwsException);
        expect(fullNames(container.read(favoritesProvider)), ['owner/r1']);
      });

      test('keeps a change that a later save stored', () async {
        final (container, store) = await controlled();
        final notifier = container.read(favoritesProvider.notifier);
        final first = notifier.toggle(repoWithId(1));
        final second = notifier.toggle(repoWithId(2));

        store.failWrite(0);
        store.completeWrite(1);

        await expectLater(first, throwsException);
        await second;
        expect(fullNames(container.read(favoritesProvider)), [
          'owner/r2',
          'owner/r1',
        ]);
        expect(fullNames((await restart()).read(favoritesProvider)), [
          'owner/r2',
          'owner/r1',
        ]);
      });

      test('waits for pending saves before restoring', () async {
        final (container, store) = await controlled();
        final notifier = container.read(favoritesProvider.notifier);
        final first = notifier.toggle(repoWithId(1));
        final second = notifier.toggle(repoWithId(2));

        store.failWrite(0);
        await expectLater(first, throwsException);

        expect(fullNames(container.read(favoritesProvider)), [
          'owner/r2',
          'owner/r1',
        ]);

        store.failWrite(1);
        await expectLater(second, throwsException);

        expect(container.read(favoritesProvider), isEmpty);
      });

      // Writes may finish out of order: here the older list is stored last,
      // so the failed change is not in storage and must be undone.
      test('restores after a failure once an earlier save finishes', () async {
        final (container, store) = await controlled();
        final notifier = container.read(favoritesProvider.notifier);
        final first = notifier.toggle(repoWithId(1));
        final second = expectLater(
          notifier.toggle(repoWithId(2)),
          throwsException,
        );

        store.failWrite(1);
        await Future<void>.delayed(Duration.zero);
        store.completeWrite(0);

        await first;
        await second;
        expect(fullNames(container.read(favoritesProvider)), ['owner/r1']);
      });

      test('keeps a change made while restoring', () async {
        final (container, store) = await controlled(stored);
        final notifier = container.read(favoritesProvider.notifier);
        final failing = expectLater(
          notifier.toggle(repoWithId(2)),
          throwsException,
        );
        final reading = store.readGate = Completer<void>();

        store.failWrite(0);
        await Future<void>.delayed(Duration.zero);
        final starring = notifier.toggle(repoWithId(3));
        reading.complete();
        store.completeWrite(1);

        await failing;
        await starring;
        // The restore read the list from before this save, so applying it
        // would drop owner/r3.
        expect(fullNames(container.read(favoritesProvider)), [
          'owner/r3',
          'owner/r2',
          'owner/r1',
        ]);
      });

      test('keeps the current favorites if storage cannot be read', () async {
        final (container, store) = await controlled(stored);
        final saving = container
            .read(favoritesProvider.notifier)
            .toggle(repoWithId(2));

        store
          ..readError = Exception('storage unavailable')
          ..failWrite(0);

        await expectLater(
          saving,
          throwsA(
            isA<Exception>().having(
              (e) => '$e',
              'message',
              contains('disk full'),
            ),
          ),
        );
        expect(fullNames(container.read(favoritesProvider)), [
          'owner/r2',
          'owner/r1',
        ]);
      });
    });
  });

  group('starredIdsProvider', () {
    test('holds the ids of the starred repositories', () async {
      final container = containerFor(await inMemoryPreferences());
      final notifier = container.read(favoritesProvider.notifier);

      await notifier.toggle(repoWithId(1));
      await notifier.toggle(repoWithId(2));

      expect(container.read(starredIdsProvider), {1, 2});
    });
  });

  group('isStarredProvider', () {
    test('follows starring and unstarring', () async {
      final container = containerFor(await inMemoryPreferences());
      final notifier = container.read(favoritesProvider.notifier);
      final listener = container.listen(isStarredProvider(1), (_, _) {});

      expect(listener.read(), isFalse);
      await notifier.toggle(repoWithId(1));
      expect(listener.read(), isTrue);
      await notifier.toggle(repoWithId(1));
      expect(listener.read(), isFalse);
    });

    // Each row watches only its own repository, so starring one row
    // doesn't rebuild the others.
    test('notifies only when that repository changes', () async {
      final container = containerFor(await inMemoryPreferences());
      final notifier = container.read(favoritesProvider.notifier);
      final changes = <bool>[];
      container.listen(
        isStarredProvider(1),
        (_, isStarred) => changes.add(isStarred),
      );

      // Dependent providers recompute when Riverpod flushes its scheduler.
      for (final id in [2, 1, 3]) {
        await notifier.toggle(repoWithId(id));
        await container.pump();
      }

      expect(changes, [true]);
    });

    // Rows scrolled out of view stop listening; their providers must not
    // pile up as the user scrolls through search results.
    test('is disposed when no longer listened to', () async {
      final container = containerFor(await inMemoryPreferences());
      final subscription = container.listen(isStarredProvider(1), (_, _) {});
      expect(container.exists(isStarredProvider(1)), isTrue);

      subscription.close();
      await container.pump();

      expect(container.exists(isStarredProvider(1)), isFalse);
    });
  });
}
