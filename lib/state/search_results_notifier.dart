import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../data/github/github_api_exception.dart';
import '../data/github/github_providers.dart';
import '../data/github/github_repo.dart';
import '../data/github/search_page.dart';

/// The results of searching for a query.
///
/// One instance per query, so a new search never shows the previous query's
/// results. Disposed once no screen shows the query.
///
/// Doesn't retry failed requests on its own: unauthenticated clients get 10
/// searches a minute, and automatic retries would use them up. Invalidate it
/// to try again.
final searchResultsProvider = AsyncNotifierProvider.autoDispose
    .family<SearchResultsNotifier, SearchResults, String>(
      SearchResultsNotifier.new,
      retry: (_, _) => null,
    );

/// The results loaded so far for a search.
class SearchResults {
  const SearchResults({
    required this.items,
    required this.totalCount,
    required this.hasMore,
    this.page = 1,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  const SearchResults.empty()
    : this(items: const [], totalCount: 0, hasMore: false);

  final List<GitHubRepo> items;

  /// Total matches reported by GitHub; may exceed what can be loaded.
  final int totalCount;

  /// Whether another page can be loaded.
  final bool hasMore;

  /// The last page loaded.
  final int page;

  /// Whether the next page is being loaded.
  final bool isLoadingMore;

  /// Why loading the next page failed, until it is retried.
  final GitHubApiException? loadMoreError;

  /// Whether paging stopped at the Search API's result limit although more
  /// repositories match.
  bool get reachedSearchLimit => !hasMore && totalCount > SearchPage.maxResults;
}

class SearchResultsNotifier extends AsyncNotifier<SearchResults> {
  SearchResultsNotifier(this.query);

  final String query;

  @override
  Future<SearchResults> build() async {
    final page = await ref
        .watch(gitHubApiClientProvider)
        .searchRepositories(query);
    return SearchResults(
      items: page.items,
      totalCount: page.totalCount,
      hasMore: page.hasMore,
    );
  }

  /// Loads and appends the next page, unless one is loading, none is left,
  /// or the last attempt failed: scrolling calls this repeatedly, so a
  /// failed page waits for [retryNextPage].
  Future<void> loadNextPage() async {
    if (state.value case final results?
        when !state.isLoading &&
            results.hasMore &&
            !results.isLoadingMore &&
            results.loadMoreError == null) {
      await _load(results);
    }
  }

  /// Loads the next page again after it failed.
  Future<void> retryNextPage() async {
    if (state.value case final results?
        when !state.isLoading && results.loadMoreError != null) {
      await _load(results);
    }
  }

  Future<void> _load(SearchResults results) async {
    // A notifier's `ref` is always the current build's, so keep this
    // build's: it is unmounted once the search reloads, and a page loaded
    // for the old results must then be dropped.
    final ref = this.ref;
    state = AsyncData(_copy(results, isLoadingMore: true));
    final nextPage = results.page + 1;
    final SearchPage page;
    try {
      page = await ref
          .read(gitHubApiClientProvider)
          .searchRepositories(query, page: nextPage);
    } on GitHubApiException catch (error) {
      if (ref.mounted) state = AsyncData(_copy(results, loadMoreError: error));
      return;
    }
    if (!ref.mounted) return;

    // Results can shift between requests, so a page may repeat a repository.
    final loadedIds = {for (final repo in results.items) repo.id};
    state = AsyncData(
      SearchResults(
        items: [
          ...results.items,
          ...page.items.where((repo) => loadedIds.add(repo.id)),
        ],
        totalCount: page.totalCount,
        hasMore: page.hasMore,
        page: nextPage,
      ),
    );
  }

  static SearchResults _copy(
    SearchResults results, {
    bool isLoadingMore = false,
    GitHubApiException? loadMoreError,
  }) {
    return SearchResults(
      items: results.items,
      totalCount: results.totalCount,
      hasMore: results.hasMore,
      page: results.page,
      isLoadingMore: isLoadingMore,
      loadMoreError: loadMoreError,
    );
  }
}
