import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Replaces the platform preferences store with an in-memory one holding
/// [data], and returns a cache over it that allows every key.
Future<SharedPreferencesWithCache> inMemoryPreferences([
  Map<String, Object> data = const {},
]) {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.withData(data);
  return reopenPreferences();
}

/// A fresh cache over the current in-memory store, as after an app restart.
Future<SharedPreferencesWithCache> reopenPreferences() {
  return SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(),
  );
}
