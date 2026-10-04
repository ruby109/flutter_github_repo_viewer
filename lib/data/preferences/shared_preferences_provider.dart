import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app's preferences, loaded once in `main()` before `runApp`.
///
/// Loading is async, so `main()` overrides this provider with the loaded
/// instance; reads are then synchronous everywhere else.
final sharedPreferencesProvider = Provider<SharedPreferencesWithCache>(
  (ref) => throw UnimplementedError(
    'Override sharedPreferencesProvider with a loaded instance',
  ),
);
