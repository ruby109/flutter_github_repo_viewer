import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../data/github/github_repo.dart';
import '../../state/favorites_notifier.dart';

/// Stars or unstars [repo], showing its current star everywhere it appears.
///
/// Rebuilds only when this repository's star changes.
class StarButton extends ConsumerWidget {
  const StarButton({super.key, required this.repo});

  final GitHubRepo repo;

  static const saveFailedMessage = "Couldn't save your stars. Try again.";

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isStarred = ref.watch(isStarredProvider(repo.id));
    return IconButton(
      isSelected: isStarred,
      tooltip: isStarred ? 'Unstar' : 'Star',
      icon: const Icon(Icons.star_border),
      selectedIcon: Icon(Icons.star, color: Colors.amber.shade700),
      onPressed: () => _toggle(context, ref),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    // Looked up now: the button may be gone when the save fails, e.g. when
    // unstarring removes its row from the Stars tab.
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await ref.read(favoritesProvider.notifier).toggle(repo);
    } on Object {
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text(saveFailedMessage)));
    }
  }
}
