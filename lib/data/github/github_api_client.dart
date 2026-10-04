import 'dart:convert';

import 'package:http/http.dart' as http;

import 'repo_detail.dart';
import 'search_page.dart';

/// Calls the GitHub REST API without authentication.
///
/// See https://docs.github.com/en/rest/search/search#search-repositories and
/// https://docs.github.com/en/rest/repos/repos#get-a-repository.
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
    final json = await _getJson(
      Uri.https(_host, '/search/repositories', {
        'q': query,
        'page': '$page',
        'per_page': '$perPage',
      }),
    );
    return SearchPage.fromJson(json, page: page, perPage: perPage);
  }

  /// Fetches the repository named [fullName] (`owner/name`).
  ///
  /// Throws an [ArgumentError] if [fullName] isn't of the form `owner/name`.
  Future<RepoDetail> fetchRepository(String fullName) async {
    final segments = fullName.split('/');
    if (segments.length != 2 || segments.any((segment) => segment.isEmpty)) {
      throw ArgumentError.value(fullName, 'fullName', 'must be "owner/name"');
    }
    final json = await _getJson(
      Uri(scheme: 'https', host: _host, pathSegments: ['repos', ...segments]),
    );
    return RepoDetail.fromJson(json);
  }

  Future<Map<String, Object?>> _getJson(Uri url) async {
    final response = await _http.get(url, headers: _headers);
    return jsonDecode(response.body) as Map<String, Object?>;
  }
}
