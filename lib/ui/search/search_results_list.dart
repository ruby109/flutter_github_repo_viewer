import 'package:flutter/material.dart';

import '../../data/github/github_api_client.dart';
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

  /// How many rows before the end loading more starts: half a page, so the
  /// next page arrives well before a fast scroll reaches the end.
  static const loadMoreThreshold = GitHubApiClient.perPage ~/ 2;

  static const searchLimitMessage =
      'Only the first 1,000 results are shown. '
      'Try a more specific search.';

  static const endOfResultsMessage = 'No more results';

  @override
  Widget build(BuildContext context) {
    final items = results.items;
    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      // The last row is the footer.
      itemCount: items.length + 1,
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

/// Shows that more results are loading, why loading them failed, that the
/// search hit GitHub's result limit, or that every result has been shown.
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
          child: CircularProgressIndicator.adaptive(),
        ),
        _ => Text(
          results.reachedSearchLimit
              ? SearchResultsList.searchLimitMessage
              : SearchResultsList.endOfResultsMessage,
          style: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      },
    );
  }
}
