import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

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

/// Installs a [ControlledPreferencesStore] holding [data] as the platform
/// store, and returns it with a cache over it.
Future<(SharedPreferencesWithCache, ControlledPreferencesStore)>
controlledPreferences([Map<String, Object> data = const {}]) async {
  final store = ControlledPreferencesStore(data);
  SharedPreferencesAsyncPlatform.instance = store;
  return (await reopenPreferences(), store);
}

/// An in-memory store whose string writes wait until the test completes or
/// fails them, in any order, and whose reads can be made to fail.
final class ControlledPreferencesStore extends InMemorySharedPreferencesAsync {
  ControlledPreferencesStore(super.data) : super.withData();

  final _writes = <Completer<void>>[];

  /// Thrown by reads while set.
  Object? readError;

  /// Reads wait for this to complete while set.
  Completer<void>? readGate;

  /// How many writes have started, finished or not.
  int get startedWrites => _writes.length;

  /// Stores the value of write [index], counting from 0, and completes it.
  Future<void> completeWrite(int index) async {
    (await _started(index)).complete();
  }

  /// Fails write [index], counting from 0, leaving the stored value as is.
  Future<void> failWrite(int index) async {
    (await _started(index)).completeError(Exception('disk full'));
  }

  /// Waits for write [index] to start; writes may start asynchronously.
  Future<Completer<void>> _started(int index) async {
    for (var i = 0; i < 100 && _writes.length <= index; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    if (_writes.length <= index) throw StateError('Write $index never started');
    return _writes[index];
  }

  @override
  Future<bool> setString(
    String key,
    String value,
    SharedPreferencesOptions options,
  ) async {
    final write = Completer<void>();
    _writes.add(write);
    await write.future;
    return super.setString(key, value, options);
  }

  @override
  Future<Map<String, Object>> getPreferences(
    GetPreferencesParameters parameters,
    SharedPreferencesOptions options,
  ) async {
    await readGate?.future;
    if (readError case final error?) throw error;
    return super.getPreferences(parameters, options);
  }
}
