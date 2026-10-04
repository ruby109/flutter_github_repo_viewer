import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The submitted search text, trimmed; empty when there is no search.
final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(
  SearchQueryNotifier.new,
);

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  /// Searches for [text]; blank text clears the search.
  void submit(String text) => state = text.trim();

  void clear() => state = '';
}
