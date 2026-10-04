import 'package:flutter/material.dart';

import '../../data/github/github_repo.dart';
import '../../state/search_results_notifier.dart';
import '../common/error_message.dart';
import '../common/repo_list_tile.dart';
import '../common/star_button.dart';

/// The loaded search results, each with a star button, loading more as the
/// end of the list comes into view.
class SearchResultsList extends StatelessWidget {
  const SearchResultsList({
    super.key,
    required this.results,
    required this.onRepoTap,
    required this.onLoadMore,
    required this.onRetryLoadMore,
  });

  final SearchResults results;
  final ValueChanged<GitHubRepo> onRepoTap;

  /// Called, possibly repeatedly, once one of the last
  /// [loadMoreThreshold] rows is built while more results can load.
  final VoidCallback onLoadMore;

  /// Called when the user retries loading more after it failed.
  final VoidCallback onRetryLoadMore;

  /// How many rows before the end loading more starts, so the next page
  /// usually arrives before the user reaches the end. Rows are built a
  /// little before they scroll into view, which adds to it.
  static const loadMoreThreshold = 5;

  static const searchLimitMessage =
      'Only the first 1,000 results are shown. '
      'Try a more specific search.';

  @override
  Widget build(BuildContext context) {
    final items = results.items;
    final hasFooter =
        results.hasMore ||
        results.loadMoreError != null ||
        results.reachedSearchLimit;
    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: items.length + (hasFooter ? 1 : 0),
      itemBuilder: (context, index) {
        // Checked as rows are built rather than on scroll, so a first page
        // that doesn't fill the screen still loads more.
        if (index >= items.length - loadMoreThreshold &&
            results.hasMore &&
            results.loadMoreError == null) {
          // Not during build: loading more changes the results.
          WidgetsBinding.instance.addPostFrameCallback((_) => onLoadMore());
        }
        if (index == items.length) {
          return _Footer(results: results, onRetry: onRetryLoadMore);
        }
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

/// Shows that more results are loading, why loading them failed, or that
/// the search hit GitHub's result limit.
class _Footer extends StatelessWidget {
  const _Footer({required this.results, required this.onRetry});

  final SearchResults results;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: switch (results) {
        SearchResults(:final loadMoreError?) => Column(
          children: [
            Text(
              describeError(context, loadMoreError).message,
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
        SearchResults(hasMore: true) => const Center(
          child: CircularProgressIndicator(),
        ),
        _ => Text(
          SearchResultsList.searchLimitMessage,
          style: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      },
    );
  }
}
