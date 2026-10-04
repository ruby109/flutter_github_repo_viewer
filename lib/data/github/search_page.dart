import 'dart:math';

import 'github_repo.dart';

/// One page of Search API results.
class SearchPage {
  const SearchPage({
    required this.items,
    required this.totalCount,
    required this.hasMore,
    this.reachedSearchLimit = false,
  });

  /// Parses page number [page] of a search requested with [perPage] results
  /// per page.
  ///
  /// Throws a [FormatException] if [json] isn't a valid search response.
  factory SearchPage.fromJson(
    Map<String, Object?> json, {
    required int page,
    required int perPage,
  }) {
    if (json case {
      'total_count': final int totalCount,
      'items': final List<Object?> rawItems,
    }) {
      final items = [for (final item in rawItems) _parseItem(item)];
      final reachesLimit = page * perPage >= maxResults;
      return SearchPage(
        items: items,
        totalCount: totalCount,
        // Empty pages end paging too, in case total_count overstates results.
        hasMore:
            items.isNotEmpty && page * perPage < min(totalCount, maxResults),
        // Only a page with results ends at the limit; an empty one ends
        // paging because GitHub had fewer results than it reported.
        reachedSearchLimit:
            items.isNotEmpty && reachesLimit && totalCount > maxResults,
      );
    }
    throw FormatException('Invalid search response JSON', json);
  }

  static GitHubRepo _parseItem(Object? json) {
    return switch (json) {
      final Map<String, Object?> repo => GitHubRepo.fromJson(repo),
      _ => throw FormatException('Invalid search result item', json),
    };
  }

  /// The Search API returns at most this many results for a query; pages
  /// beyond it fail with 422.
  static const maxResults = 1000;

  final List<GitHubRepo> items;

  /// Total matches reported by GitHub; may exceed [maxResults].
  final int totalCount;

  /// Whether requesting the next page can return more results.
  final bool hasMore;

  /// Whether this page ended paging at [maxResults] although more
  /// repositories match.
  final bool reachedSearchLimit;
}
