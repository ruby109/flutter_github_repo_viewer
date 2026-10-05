/// Real avatar images for widget and golden tests, without the network.
library;

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/misc.dart' show Override;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:github_repo_viewer/data/avatars/avatar_cache.dart';
import 'package:github_repo_viewer/data/avatars/avatar_providers.dart';

/// Avatars served from `test/fixtures/avatars` through a real [AvatarCache]
/// over a temporary directory, deleted after the test.
class AvatarFixtures {
  /// `https://avatars.githubusercontent.com/u/<id>?...` is served from
  /// `test/fixtures/avatars/<id>`; any other URL fails with 404, and every
  /// URL fails while [offline].
  AvatarFixtures() {
    // Avatars decoded by an earlier test would skip loading entirely.
    imageCache
      ..clear()
      ..clearLiveImages();
    addTearDown(() => _directory.deleteSync(recursive: true));
  }

  /// The URLs downloaded so far (cache misses only).
  final requested = <Uri>[];

  /// Whether downloads fail as if there were no connection.
  var offline = false;

  final _directory = Directory.systemTemp.createTempSync('avatar_fixtures');

  late final cache = AvatarCache(
    MockClient((request) async {
      if (offline) throw http.ClientException('offline', request.url);
      requested.add(request.url);
      final file = _fixtureFor(request.url);
      return file == null
          ? http.Response('', 404)
          : http.Response.bytes(file.readAsBytesSync(), 200);
    }),
    directory: _directory,
  );

  /// Put this in the `ProviderScope` of the widgets under test.
  Override get override => avatarCacheProvider.overrideWithValue(cache);

  static File? _fixtureFor(Uri url) {
    if (url.host != 'avatars.githubusercontent.com') return null;
    if (url.pathSegments case ['u', final userId]) {
      final file = File('test/fixtures/avatars/$userId');
      if (file.existsSync()) return file;
    }
    return null;
  }
}

/// Waits until every image on screen has loaded and decoded, or failed.
///
/// Loading reads and writes files, and decoding runs in the engine; both
/// complete on the real event loop, which the test's fake async zone
/// doesn't run. So this alternates real time ([WidgetTester.runAsync]) with
/// pumps, which deliver the results to the widgets.
Future<void> loadImages(WidgetTester tester) async {
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump();
    if (i > 1 && imageCache.pendingImageCount == 0) return;
  }
  throw StateError('Images are still loading');
}
