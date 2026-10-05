import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/misc.dart' show ProviderException;

import 'package:github_repo_viewer/data/preferences/shared_preferences_provider.dart';

import '../../helpers/preferences.dart';

void main() {
  group('sharedPreferencesLoaderProvider', () {
    test('loads the stored app keys', () async {
      await inMemoryPreferences({
        PreferenceKeys.favorites: '[]',
        'other': 'value',
      });
      final container = ProviderContainer.test();

      final preferences = await container.read(
        sharedPreferencesLoaderProvider.future,
      );

      expect(preferences.keys, {PreferenceKeys.favorites});
    });

    // The startup screen offers Retry instead: retrying on its own would
    // keep the user waiting on a blank screen.
    test('does not retry a failed load by itself', () async {
      final (_, store) = await controlledPreferences();
      store.readError = Exception('corrupt file');
      final container = ProviderContainer.test();
      container.listen(sharedPreferencesLoaderProvider, (_, _) {});

      await expectLater(
        container.read(sharedPreferencesLoaderProvider.future),
        throwsA(isA<Exception>()),
      );
      store.readError = null;
      await Future<void>.delayed(const Duration(seconds: 1));

      expect(container.read(sharedPreferencesLoaderProvider).hasError, isTrue);
    });

    test('loads again when invalidated after a failure', () async {
      final (_, store) = await controlledPreferences({
        PreferenceKeys.favorites: '[]',
      });
      store.readError = Exception('corrupt file');
      final container = ProviderContainer.test();
      container.listen(sharedPreferencesLoaderProvider, (_, _) {});
      await expectLater(
        container.read(sharedPreferencesLoaderProvider.future),
        throwsA(isA<Exception>()),
      );

      store.readError = null;
      container.invalidate(sharedPreferencesLoaderProvider);
      final preferences = await container.read(
        sharedPreferencesLoaderProvider.future,
      );

      expect(preferences.get(PreferenceKeys.favorites), '[]');
    });
  });

  group('sharedPreferencesProvider', () {
    test('returns the loaded preferences', () async {
      await inMemoryPreferences();
      final container = ProviderContainer.test();
      final loaded = await container.read(
        sharedPreferencesLoaderProvider.future,
      );

      expect(container.read(sharedPreferencesProvider), same(loaded));
    });

    // Reading preferences synchronously is only possible once they have
    // loaded; the startup widget waits for that, and reading earlier must
    // fail loudly.
    test('throws before the preferences have loaded', () async {
      final (_, store) = await controlledPreferences();
      store.readGate = Completer<void>();
      final container = ProviderContainer.test();

      // Riverpod 3 wraps errors thrown while building a provider.
      expect(
        () => container.read(sharedPreferencesProvider),
        throwsA(
          isA<ProviderException>().having(
            (e) => e.exception,
            'exception',
            isA<AsyncValueIsLoadingException>(),
          ),
        ),
      );
      store.readGate!.complete();
    });

    test('returns the overriding instance', () async {
      final preferences = await inMemoryPreferences();
      final container = ProviderContainer.test(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      );

      expect(container.read(sharedPreferencesProvider), same(preferences));
    });
  });
}
