import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The keys the app stores in preferences.
abstract final class PreferenceKeys {
  /// The starred repositories, as a JSON array.
  static const favorites = 'favorites';

  /// Every key above. Only these are loaded at startup, so anything else in
  /// the platform store doesn't slow the app's first screen.
  static const all = {favorites};
}

/// Loads the app's preferences, once, while the app starts.
///
/// Doesn't retry a failed load by itself: the startup screen shows the error
/// with a Retry button, which invalidates this provider to load again.
final sharedPreferencesLoaderProvider =
    FutureProvider<SharedPreferencesWithCache>(
      (ref) => SharedPreferencesWithCache.create(
        cacheOptions: const SharedPreferencesWithCacheOptions(
          allowList: PreferenceKeys.all,
        ),
      ),
      retry: (_, _) => null,
    );

/// The loaded preferences, read synchronously.
///
/// The startup widget shows the app only once
/// [sharedPreferencesLoaderProvider] has loaded, so every screen can read
/// stored data, such as favorites, without a loading state. Reading this
/// earlier throws.
final sharedPreferencesProvider = Provider<SharedPreferencesWithCache>(
  (ref) => ref.watch(sharedPreferencesLoaderProvider).requireValue,
);
