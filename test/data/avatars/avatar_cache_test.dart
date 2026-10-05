import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:github_repo_viewer/data/avatars/avatar_cache.dart';

void main() {
  group('AvatarCache', () {
    final url = Uri.parse('https://avatars.githubusercontent.com/u/1?v=4&s=80');
    final avatar = Uint8List.fromList([1, 2, 3]);

    late Directory directory;
    late List<Uri> requests;
    late DateTime now;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('avatar_cache_test');
      requests = [];
      now = DateTime(2026, 10, 1, 12);
    });

    tearDown(() => directory.deleteSync(recursive: true));

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

    Future<http.Response> found(http.Request _) async =>
        http.Response.bytes(avatar, 200);

    Future<http.Response> offline(http.Request _) async =>
        throw http.ClientException('offline');

    List<File> cachedFiles() => directory.listSync().whereType<File>().toList();

    test('downloads an avatar it has not seen', () async {
      final cache = cacheWith(found);

      expect(await cache.load(url), avatar);
      expect(requests, [url]);
    });

    test('reads an avatar it has seen from disk', () async {
      final cache = cacheWith(found);
      await cache.load(url);

      expect(await cache.load(url), avatar);
      expect(requests, hasLength(1));
    });

    // A new cache over the same directory, as after an app restart.
    test('keeps avatars across restarts', () async {
      await cacheWith(found).load(url);

      final restarted = cacheWith(offline);

      expect(await restarted.load(url), avatar);
      expect(requests, hasLength(1));
    });

    test('stores different URLs separately', () async {
      final cache = cacheWith(
        (request) async =>
            http.Response.bytes([request.url.pathSegments.last.length], 200),
      );
      final other = Uri.parse('https://avatars.githubusercontent.com/u/22?v=4');

      final first = await cache.load(url);
      final second = await cache.load(other);

      expect(first, isNot(second));
      expect(cachedFiles(), hasLength(2));
    });

    group('after the maximum age', () {
      Future<AvatarCache> cachedWeekAgo(
        Future<http.Response> Function(http.Request) respond,
      ) async {
        await cacheWith(found).load(url);
        now = now.add(AvatarCache.maxAge + const Duration(minutes: 1));
        return cacheWith(respond);
      }

      test('downloads the avatar again', () async {
        final updated = Uint8List.fromList([9, 9]);
        final cache = await cachedWeekAgo(
          (_) async => http.Response.bytes(updated, 200),
        );

        expect(await cache.load(url), updated);
        expect(requests, hasLength(2));
      });

      // Offline, an old avatar beats a placeholder.
      test('keeps showing the old avatar if that fails', () async {
        final cache = await cachedWeekAgo(offline);

        expect(await cache.load(url), avatar);
      });
    });

    group('when the download fails', () {
      test('throws and stores nothing when offline', () async {
        final cache = cacheWith(offline);

        await expectLater(cache.load(url), throwsA(isA<Exception>()));
        expect(cachedFiles(), isEmpty);
      });

      test('throws and stores nothing for a non-200 status', () async {
        final cache = cacheWith((_) async => http.Response('', 404));

        await expectLater(cache.load(url), throwsA(isA<HttpException>()));
        expect(cachedFiles(), isEmpty);
      });

      test('throws and stores nothing for an empty body', () async {
        final cache = cacheWith((_) async => http.Response.bytes([], 200));

        await expectLater(cache.load(url), throwsA(isA<HttpException>()));
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
          await cache.load(avatarOf(user));
          now = now.add(const Duration(minutes: 1));
        }
        return cache;
      }

      Future<bool> isCached(AvatarCache cache, int user) async {
        requests.clear();
        await cache.load(avatarOf(user));
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
        await cache.load(avatarOf(1));
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
        File('${directory.path}/leftover.tmp').writeAsBytesSync([1]);

        await cache.trim();

        expect(
          cachedFiles().map((file) => file.path),
          everyElement(isNot(endsWith('.tmp'))),
        );
      });

      test('does nothing before anything is cached', () async {
        directory.deleteSync(recursive: true);

        await cacheWith(found).trim();

        directory.createSync();
      });
    });

    // Reading an avatar marks it as used, but doesn't make it fresh.
    test(
      'still refreshes an avatar seen often after the maximum age',
      () async {
        final cache = cacheWith(found);
        await cache.load(url);
        now = now.add(AvatarCache.maxAge - const Duration(minutes: 1));
        await cache.load(url);
        now = now.add(const Duration(minutes: 2));

        await cache.load(url);

        expect(requests, hasLength(2));
      },
    );
  });
}
