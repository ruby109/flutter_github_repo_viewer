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

/// The ids of the starred repositories, for constant-time lookups.
final starredIdsProvider = Provider<Set<int>>(
  (ref) => {for (final repo in ref.watch(favoritesProvider)) repo.id},
);

/// Whether the repository with this id is starred.
///
/// Notifies only when this repository's star changes, so a list row
/// watching it doesn't rebuild when another row is starred. Disposed once
/// no row watches it, so ids scrolled past don't accumulate.
final isStarredProvider = Provider.autoDispose.family<bool, int>(
  (ref, id) => ref.watch(starredIdsProvider).contains(id),
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

  /// Stars [repo] if it isn't starred, otherwise unstars it.
  ///
  /// Updates [state] at once so every screen reflects the change, then saves.
  Future<void> toggle(GitHubRepo repo) {
    final isStarred = state.any((favorite) => favorite.id == repo.id);
    state = isStarred
        ? [
            for (final favorite in state)
              if (favorite.id != repo.id) favorite,
          ]
        : [repo, ...state];

    return ref
        .read(sharedPreferencesProvider)
        .setString(storageKey, jsonEncode(state));
  }
}
