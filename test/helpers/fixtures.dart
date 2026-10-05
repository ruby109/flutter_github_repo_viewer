/// Real GitHub API data saved by `tool/fetch_fixtures.dart`.
library;

import 'dart:convert';
import 'dart:io';

/// The first 20 Search API results for `flutter`, as GitHub returned them.
Map<String, Object?> searchFixture() => _read('search_flutter.json');

/// The Repository API response for `flutter/flutter`, the first search
/// result.
Map<String, Object?> repoDetailFixture() => _read('repo_flutter_flutter.json');

Map<String, Object?> _read(String name) {
  final body = File('test/fixtures/$name').readAsStringSync();
  return jsonDecode(body) as Map<String, Object?>;
}
