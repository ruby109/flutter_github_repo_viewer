import 'dart:convert';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../data/github/github_repo.dart';
import '../data/preferences/shared_preferences_provider.dart';

/// The starred repositories, most recently starred first.
///
/// The single source of truth for stars: every screen reads it, so starring
/// anywhere updates everywhere.
final favoritesProvider = NotifierProvider<FavoritesNotifier, List<GitHubRepo>>(
  FavoritesNotifier.new,
);

class FavoritesNotifier extends Notifier<List<GitHubRepo>> {
  /// The preferences key holding the favorites as a JSON array.
  static const storageKey = 'favorites';

  @override
  List<GitHubRepo> build() {
    final stored = ref.watch(sharedPreferencesProvider).getString(storageKey);
    if (stored == null) return const [];

    return switch (jsonDecode(stored)) {
      final List<Object?> items => [
        for (final item in items)
          if (item case final Map<String, Object?> json)
            GitHubRepo.fromJson(json),
      ],
      _ => const [],
    };
  }
}
