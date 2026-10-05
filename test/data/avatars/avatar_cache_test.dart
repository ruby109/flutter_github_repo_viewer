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

    test('removes the oldest avatars once over its size limit', () async {
      final cache = cacheWith(
        (_) async => http.Response.bytes(List.filled(400, 0), 200),
        maxBytes: 1000,
      );
      Uri avatarOf(int user) =>
          Uri.parse('https://avatars.githubusercontent.com/u/$user?v=4');

      for (var user = 1; user <= 3; user++) {
        await cache.load(avatarOf(user));
        // Each avatar is written a minute after the previous one.
        now = now.add(const Duration(minutes: 1));
      }

      final remaining = cachedFiles();
      expect(
        remaining.fold<int>(0, (sum, file) => sum + file.lengthSync()),
        lessThanOrEqualTo(1000),
      );
      // The first avatar was evicted, so it is downloaded again.
      requests.clear();
      await cache.load(avatarOf(1));
      expect(requests, [avatarOf(1)]);
    });
  });
}
