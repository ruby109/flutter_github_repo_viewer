import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:github_repo_viewer/data/avatars/avatar_cache.dart';

void main() {
  group('AvatarCache', () {
    /// An owner's `avatar_url`, as the API returns it.
    final url = Uri.parse('https://avatars.githubusercontent.com/u/1?v=4');

    Uri sized(Uri avatar, int pixels) => avatar.replace(
      queryParameters: {...avatar.queryParameters, 's': '$pixels'},
    );

    late Directory directory;
    late List<Uri> requests;
    late DateTime now;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('avatar_cache_test');
      requests = [];
      now = DateTime(2026, 10, 1, 12);
    });

    tearDown(() {
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });

    /// A cache over [directory] whose downloads answer with [respond].
    AvatarCache cacheWith(
      Future<http.Response> Function(http.Request request) respond, {
      int maxBytes = 1024 * 1024,
    }) {
      return AvatarCache(
        MockClient((request) {
          requests.add(request.url);
          return respond(request);
        }),
        directory: directory,
        maxBytes: maxBytes,
        now: () => now,
      );
    }

    /// Answers with the requested size as text, so a test can tell which
    /// size it got.
    Future<http.Response> found(http.Request request) async => http.Response(
      'size ${request.url.queryParameters['s'] ?? 'original'}',
      200,
    );

    Future<http.Response> offline(http.Request _) async =>
        throw http.ClientException('offline');

    Future<String> load(AvatarCache cache, int pixels, {Uri? avatar}) async =>
        utf8.decode(await cache.load(avatar ?? url, pixels: pixels));

    List<File> cachedFiles() => directory.listSync().whereType<File>().toList();

    test('downloads an avatar at the size asked for', () async {
      final cache = cacheWith(found);

      expect(await load(cache, 80), 'size 80');
      expect(requests, [sized(url, 80)]);
    });

    // Only GitHub's avatar host is known to accept the size parameter.
    test('downloads other images as they are', () async {
      final cache = cacheWith(found);
      final other = Uri.parse('https://example.com/a.png?v=4');

      expect(await load(cache, 80, avatar: other), 'size original');
      expect(await load(cache, 288, avatar: other), 'size original');
      expect(requests, [other]);
    });

    test('reads an avatar it has seen from disk', () async {
      final cache = cacheWith(found);
      await load(cache, 80);

      expect(await load(cache, 80), 'size 80');
      expect(requests, hasLength(1));
    });

    // A new cache over the same directory, as after an app restart.
    test('keeps avatars across restarts', () async {
      await load(cacheWith(found), 80);

      final restarted = cacheWith(offline);

      expect(await load(restarted, 80), 'size 80');
      expect(requests, hasLength(1));
    });

    test('keeps different avatars apart', () async {
      final cache = cacheWith(found);
      final other = Uri.parse('https://avatars.githubusercontent.com/u/22?v=4');

      await load(cache, 80);
      await load(cache, 80, avatar: other);

      expect(cachedFiles(), hasLength(2));
      expect(requests, [sized(url, 80), sized(other, 80)]);
    });

    group('with another size cached', () {
      // The list shows 120 pixel avatars, the detail screen 288.
      test('scales a larger one down instead of downloading', () async {
        final cache = cacheWith(found);
        await load(cache, 288);

        expect(await load(cache, 120), 'size 288');
        expect(requests, [sized(url, 288)]);
      });

      test('uses the closest larger one', () async {
        final cache = cacheWith(found);
        // 400 is larger than 288, so it is downloaded too.
        await load(cache, 288);
        await load(cache, 400);

        expect(await load(cache, 120), 'size 288');
      });

      test(
        'downloads the size asked for if only a smaller one is cached',
        () async {
          final cache = cacheWith(found);
          await load(cache, 120);

          expect(await load(cache, 288), 'size 288');
          expect(requests, [sized(url, 120), sized(url, 288)]);
        },
      );

      // Offline, a blurry avatar beats a placeholder.
      test('falls back to a smaller one when offline', () async {
        await load(cacheWith(found), 120);

        expect(await load(cacheWith(offline), 288), 'size 120');
      });
    });

    group('after the maximum age', () {
      Future<AvatarCache> cachedWeekAgo(
        Future<http.Response> Function(http.Request) respond,
      ) async {
        await load(cacheWith(found), 80);
        now = now.add(AvatarCache.maxAge + const Duration(minutes: 1));
        return cacheWith(respond);
      }

      test('downloads the avatar again', () async {
        final cache = await cachedWeekAgo(
          (_) async => http.Response('updated', 200),
        );

        expect(await load(cache, 80), 'updated');
        expect(requests, hasLength(2));
      });

      test('keeps showing the old avatar if that fails', () async {
        final cache = await cachedWeekAgo(offline);

        expect(await load(cache, 80), 'size 80');
      });
    });

    // Caching is best effort: a full disk mustn't hide a downloaded avatar.
    test('returns a download it cannot store', () async {
      // A file where the cache directory should be makes every write fail.
      directory.deleteSync(recursive: true);
      File(directory.path).writeAsStringSync('not a directory');
      addTearDown(() => File(directory.path).deleteSync());

      expect(await load(cacheWith(found), 80), 'size 80');
    });

    group('when the download fails', () {
      test('throws and stores nothing when offline', () async {
        final cache = cacheWith(offline);

        await expectLater(
          cache.load(url, pixels: 80),
          throwsA(isA<Exception>()),
        );
        expect(cachedFiles(), isEmpty);
      });

      test('throws and stores nothing for a non-200 status', () async {
        final cache = cacheWith((_) async => http.Response('', 404));

        await expectLater(
          cache.load(url, pixels: 80),
          throwsA(isA<HttpException>()),
        );
        expect(cachedFiles(), isEmpty);
      });

      test('throws and stores nothing for an empty body', () async {
        final cache = cacheWith((_) async => http.Response.bytes([], 200));

        await expectLater(
          cache.load(url, pixels: 80),
          throwsA(isA<HttpException>()),
        );
        expect(cachedFiles(), isEmpty);
      });
    });

    group('trim', () {
      Uri avatarOf(int user) =>
          Uri.parse('https://avatars.githubusercontent.com/u/$user?v=4');

      /// A cache holding avatars 1 to [count], 400 bytes each, loaded a
      /// minute apart, with room for [maxBytes].
      Future<AvatarCache> filled(int count, {required int maxBytes}) async {
        final cache = cacheWith(
          (_) async => http.Response.bytes(List.filled(400, 0), 200),
          maxBytes: maxBytes,
        );
        for (var user = 1; user <= count; user++) {
          await cache.load(avatarOf(user), pixels: 80);
          now = now.add(const Duration(minutes: 1));
        }
        return cache;
      }

      Future<bool> isCached(AvatarCache cache, int user) async {
        requests.clear();
        await cache.load(avatarOf(user), pixels: 80);
        return requests.isEmpty;
      }

      // Scanning the directory on every write would slow loading a list.
      test('only removes files when asked', () async {
        await filled(3, maxBytes: 1000);

        expect(cachedFiles(), hasLength(3));
      });

      test('removes the least recently used avatars over the limit', () async {
        final cache = await filled(3, maxBytes: 1000);
        // Avatar 1 was seen again most recently, so avatar 2 is the least
        // recently used.
        await cache.load(avatarOf(1), pixels: 80);
        now = now.add(const Duration(minutes: 1));

        await cache.trim();

        expect(
          cachedFiles().fold<int>(0, (sum, file) => sum + file.lengthSync()),
          lessThanOrEqualTo(1000),
        );
        expect(await isCached(cache, 1), isTrue);
        expect(await isCached(cache, 3), isTrue);
        expect(await isCached(cache, 2), isFalse);
      });

      // Old files are the offline fallback, so age alone doesn't remove them.
      test('keeps old avatars while under the limit', () async {
        final cache = await filled(2, maxBytes: 1000);
        now = now.add(AvatarCache.maxAge * 2);

        await cache.trim();

        expect(cachedFiles(), hasLength(2));
      });

      // Left behind if the app is killed while writing.
      test('removes leftover temporary files', () async {
        final cache = await filled(1, maxBytes: 1000);
        File('${directory.path}/leftover.tmp')
          ..writeAsBytesSync([1])
          ..setLastModifiedSync(now.subtract(const Duration(hours: 1)));

        await cache.trim();

        expect(
          cachedFiles().map((file) => file.path),
          everyElement(isNot(endsWith('.tmp'))),
        );
      });

      // The app can go to the background while an avatar is being stored.
      test('keeps temporary files still being written', () async {
        final cache = await filled(1, maxBytes: 1000);
        File('${directory.path}/writing.tmp')
          ..writeAsBytesSync([1])
          ..setLastModifiedSync(now);

        await cache.trim();

        expect(
          cachedFiles().map((file) => file.path),
          contains(endsWith('writing.tmp')),
        );
      });

      // Trimming is optional upkeep, so it mustn't fail the app.
      test('copes with a directory it cannot read', () async {
        final cache = await filled(1, maxBytes: 1000);
        Process.runSync('chmod', ['000', directory.path]);
        addTearDown(() => Process.runSync('chmod', ['700', directory.path]));

        await cache.trim();
      });

      // Two passes picking the same file to delete must not fail.
      test('copes with passes running at the same time', () async {
        final cache = await filled(3, maxBytes: 500);

        await Future.wait([cache.trim(), cache.trim()]);

        expect(cachedFiles(), hasLength(1));
      });

      test('copes with files removed by someone else', () async {
        final cache = await filled(3, maxBytes: 500);
        for (final file in cachedFiles()) {
          file.deleteSync();
        }

        await cache.trim();

        expect(await isCached(cache, 1), isFalse);
      });

      test('does nothing before anything is cached', () async {
        directory.deleteSync(recursive: true);

        await cacheWith(found).trim();
      });
    });

    // E.g. the directory is removed between checking and listing it.
    test(
      'downloads while the directory cannot be read, then retries',
      () async {
        await load(cacheWith(found), 80);
        final cache = cacheWith(found);
        Process.runSync('chmod', ['000', directory.path]);
        addTearDown(() => Process.runSync('chmod', ['700', directory.path]));

        expect(await load(cache, 80), 'size 80');

        Process.runSync('chmod', ['700', directory.path]);
        expect(await load(cache, 80), 'size 80');
        expect(requests, hasLength(2));
      },
    );

    // trim can delete a file between load finding it and reading it.
    group('with a cached file it cannot read', () {
      /// Replaces the cached [pixels] file with a directory, which exists
      /// and is fresh but fails to read.
      void unreadable(int pixels) {
        final file = cachedFiles().singleWhere(
          (file) => file.path.endsWith('_$pixels'),
        );
        file.deleteSync();
        Directory(file.path).createSync();
      }

      test('downloads the avatar again', () async {
        final cache = cacheWith(found);
        await load(cache, 80);
        unreadable(80);

        expect(await load(cache, 80), 'size 80');
        expect(requests, hasLength(2));
      });

      test('falls back to another size when offline', () async {
        var online = true;
        final cache = cacheWith(
          (request) => online ? found(request) : offline(request),
        );
        await load(cache, 120);
        await load(cache, 288);
        unreadable(288);
        online = false;

        expect(await load(cache, 288), 'size 120');
      });
    });

    // The size load returned may be any cached one, so all of them go.
    test('remove deletes every size of an avatar', () async {
      final cache = cacheWith(found);
      await load(cache, 120);
      await load(cache, 288);

      await cache.remove(url);

      expect(cachedFiles(), isEmpty);
      requests.clear();
      expect(await load(cache, 120), 'size 120');
      expect(requests, [sized(url, 120)]);
    });

    test('remove copes with files already gone', () async {
      final cache = cacheWith(found);
      await load(cache, 120);
      for (final file in cachedFiles()) {
        file.deleteSync();
      }

      await cache.remove(url);
    });

    // Reading an avatar marks it as used, but doesn't make it fresh.
    test(
      'still refreshes an avatar seen often after the maximum age',
      () async {
        final cache = cacheWith(found);
        await load(cache, 80);
        now = now.add(AvatarCache.maxAge - const Duration(minutes: 1));
        await load(cache, 80);
        now = now.add(const Duration(minutes: 2));

        await load(cache, 80);

        expect(requests, hasLength(2));
      },
    );
  });
}
