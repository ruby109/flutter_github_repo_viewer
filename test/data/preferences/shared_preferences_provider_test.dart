import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/misc.dart' show ProviderException;

import 'package:github_repo_viewer/data/preferences/shared_preferences_provider.dart';

import '../../helpers/preferences.dart';

void main() {
  group('sharedPreferencesProvider', () {
    // Loading preferences is async, so main() loads them before runApp and
    // overrides this provider; forgetting to must fail loudly.
    test('throws when not overridden', () {
      final container = ProviderContainer.test();

      // Riverpod 3 wraps errors thrown while building a provider.
      expect(
        () => container.read(sharedPreferencesProvider),
        throwsA(
          isA<ProviderException>().having(
            (e) => e.exception,
            'exception',
            isA<UnimplementedError>(),
          ),
        ),
      );
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
