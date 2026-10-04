import 'dart:convert';

import 'package:http/http.dart' as http;

import 'search_page.dart';

/// Calls the GitHub REST API without authentication.
///
/// See https://docs.github.com/en/rest/search/search#search-repositories.
class GitHubApiClient {
  GitHubApiClient(this._http);

  final http.Client _http;

  /// Results requested per search page.
  static const perPage = 30;

  static const _host = 'api.github.com';

  static const _headers = {
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
  };

  /// Searches repositories matching [query] and returns page [page],
  /// starting at 1.
  ///
  /// Throws an [ArgumentError] if [query] is blank.
  Future<SearchPage> searchRepositories(String query, {int page = 1}) async {
    if (query.trim().isEmpty) {
      throw ArgumentError.value(query, 'query', 'must not be blank');
    }
    final url = Uri.https(_host, '/search/repositories', {
      'q': query,
      'page': '$page',
      'per_page': '$perPage',
    });
    final response = await _http.get(url, headers: _headers);
    final json = jsonDecode(response.body) as Map<String, Object?>;
    return SearchPage.fromJson(json, page: page, perPage: perPage);
  }
}
