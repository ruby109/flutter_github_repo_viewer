import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../data/github/github_providers.dart';
import '../data/github/github_repo.dart';

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
  });

  const SearchResults.empty()
    : this(items: const [], totalCount: 0, hasMore: false);

  final List<GitHubRepo> items;

  /// Total matches reported by GitHub; may exceed what can be loaded.
  final int totalCount;

  /// Whether another page can be loaded.
  final bool hasMore;
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
}
