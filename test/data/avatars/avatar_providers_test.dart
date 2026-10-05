import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:github_repo_viewer/data/avatars/avatar_providers.dart';

void main() {
  group('avatarCacheProvider', () {
    late Directory directory;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('avatar_providers');
    });

    tearDown(() => directory.deleteSync(recursive: true));

    ProviderContainer containerFor(Directory directory) =>
        ProviderContainer.test(
          overrides: [
            avatarCacheDirectoryProvider.overrideWithValue(directory),
          ],
        );

    test('caches in the given directory', () {
      final container = containerFor(directory);

      expect(container.read(avatarCacheProvider).directory, directory);
    });

    // Like SDWebImage: trimming on every write would slow loading a list.
    testWidgets('trims the cache when the app goes to the background', (
      tester,
    ) async {
      final leftover = File('${directory.path}/leftover.tmp')
        ..writeAsBytesSync([1])
        ..setLastModifiedSync(
          DateTime.now().subtract(const Duration(hours: 1)),
        );
      containerFor(directory).read(avatarCacheProvider);

      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      // Trimming reads the directory on the real event loop; pumps deliver
      // its results to the fake async zone the callback started in.
      for (var i = 0; i < 20 && leftover.existsSync(); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await tester.pump();
      }

      expect(leftover.existsSync(), isFalse);
    });
  });
}
