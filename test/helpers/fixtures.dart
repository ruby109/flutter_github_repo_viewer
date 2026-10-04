/// Real GitHub API data saved by `tool/fetch_search_fixtures.dart`.
library;

import 'dart:convert';
import 'dart:io';

/// The first 10 Search API results for `flutter`, as GitHub returned them.
Map<String, Object?> searchFixture() {
  final body = File('test/fixtures/search_flutter.json').readAsStringSync();
  return jsonDecode(body) as Map<String, Object?>;
}
