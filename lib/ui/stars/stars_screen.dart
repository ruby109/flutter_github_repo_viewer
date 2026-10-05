import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../data/github/github_repo.dart';
import '../../state/favorites_notifier.dart';
import '../common/repo_list_tile.dart';
import '../common/star_button.dart';
import '../common/status_message.dart';

/// The starred repositories, most recently starred first.
///
/// Tapping a star unstars the repository, which removes its row at once;
/// stars changed on other screens show here immediately too.
class StarsScreen extends ConsumerWidget {
  const StarsScreen({super.key, required this.onRepoTap});

  final ValueChanged<GitHubRepo> onRepoTap;

  static const emptyTitle = 'No stars yet';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Stars')),
      body: favorites.isEmpty
          ? const StatusMessage(
              icon: Icons.star_border,
              title: emptyTitle,
              message: 'Star repositories in Search to keep them here.',
            )
          : ListView.builder(
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final repo = favorites[index];
                return RepoListTile(
                  key: ValueKey(repo.id),
                  repo: repo,
                  trailing: StarButton(repo: repo),
                  onTap: () => onRepoTap(repo),
                );
              },
            ),
    );
  }
}
