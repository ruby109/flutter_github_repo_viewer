import 'package:flutter/material.dart';

import '../../data/github/github_repo.dart';
import '../../state/search_results_notifier.dart';
import '../common/repo_list_tile.dart';
import '../common/star_button.dart';

/// The loaded search results, each with a star button.
class SearchResultsList extends StatelessWidget {
  const SearchResultsList({
    super.key,
    required this.results,
    required this.onRepoTap,
  });

  final SearchResults results;
  final ValueChanged<GitHubRepo> onRepoTap;

  @override
  Widget build(BuildContext context) {
    final items = results.items;
    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final repo = items[index];
        return RepoListTile(
          key: ValueKey(repo.id),
          repo: repo,
          trailing: StarButton(repo: repo),
          onTap: () => onRepoTap(repo),
        );
      },
    );
  }
}
