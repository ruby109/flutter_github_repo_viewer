import 'dart:convert';

import 'package:http/http.dart' as http;

import 'github_api_exception.dart';
import 'repo_detail.dart';
import 'search_page.dart';

/// Calls the GitHub REST API without authentication.
///
/// See https://docs.github.com/en/rest/search/search#search-repositories and
/// https://docs.github.com/en/rest/repos/repos#get-a-repository.
class GitHubApiClient {
  /// Requests that take longer than [timeout] fail with a
  /// [NetworkException]. [now] is the clock used to compute retry times;
  /// tests can fix it.
  GitHubApiClient(
    this._http, {
    this._timeout = defaultTimeout,
    this._now = DateTime.now,
  });

  final http.Client _http;
  final Duration _timeout;
  final DateTime Function() _now;

  static const defaultTimeout = Duration(seconds: 15);

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
    final http.Response response;
    // Any exception from the transport means the request didn't complete:
    // ClientException (socket errors), TimeoutException, TLS errors, etc.
    // Errors (bugs) still propagate.
    try {
      response = await _http.get(url, headers: _headers).timeout(_timeout);
    } on Exception catch (error) {
      throw NetworkException(error);
    }
    if (_isRateLimited(response)) {
      throw RateLimitException(retryAt: _retryAt(response.headers));
    }
    switch (response.statusCode) {
      case >= 200 && < 300:
        break;
      case 404:
        throw const NotFoundException();
      case final statusCode:
        throw HttpStatusException(statusCode);
    }
    return jsonDecode(response.body) as Map<String, Object?>;
  }

  // https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api#exceeding-the-rate-limit
  bool _isRateLimited(http.Response response) {
    return switch (response.statusCode) {
      429 => true,
      403 =>
        response.headers.containsKey('retry-after') ||
            response.headers['x-ratelimit-remaining'] == '0' ||
            response.body.toLowerCase().contains('rate limit'),
      _ => false,
    };
  }

  DateTime? _retryAt(Map<String, String> headers) {
    if (int.tryParse(headers['retry-after'] ?? '') case final seconds?) {
      return _now().add(Duration(seconds: seconds));
    }
    if (headers['x-ratelimit-remaining'] == '0') {
      if (int.tryParse(headers['x-ratelimit-reset'] ?? '') case final epoch?) {
        return DateTime.fromMillisecondsSinceEpoch(epoch * 1000, isUtc: true);
      }
    }
    return null;
  }
}
