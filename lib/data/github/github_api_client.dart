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

  /// Results requested per search page: the most GitHub allows, so
  /// scrolling through results spends as few of the 10 searches a minute as
  /// possible.
  static const perPage = 100;

  /// The last page within the Search API's [SearchPage.maxResults] limit;
  /// later pages fail with 422.
  static const maxPage = (SearchPage.maxResults + perPage - 1) ~/ perPage;

  static const _host = 'api.github.com';

  static const _headers = {
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
  };

  /// Searches repositories matching [query] and returns page [page],
  /// starting at 1.
  ///
  /// Throws an [ArgumentError] if [query] is blank, or a [RangeError] if
  /// [page] isn't between 1 and [maxPage].
  Future<SearchPage> searchRepositories(String query, {int page = 1}) async {
    if (query.trim().isEmpty) {
      throw ArgumentError.value(query, 'query', 'must not be blank');
    }
    RangeError.checkValueInInterval(page, 1, maxPage, 'page');
    return _get(
      Uri.https(_host, '/search/repositories', {
        'q': query,
        'page': '$page',
        'per_page': '$perPage',
      }),
      (json) => SearchPage.fromJson(json, page: page, perPage: perPage),
    );
  }

  /// Fetches the repository named [fullName] (`owner/name`).
  ///
  /// Throws an [ArgumentError] if [fullName] isn't of the form `owner/name`.
  Future<RepoDetail> fetchRepository(String fullName) async {
    final segments = fullName.split('/');
    if (segments.length != 2 || segments.any((segment) => segment.isEmpty)) {
      throw ArgumentError.value(fullName, 'fullName', 'must be "owner/name"');
    }
    return _get(
      Uri(scheme: 'https', host: _host, pathSegments: ['repos', ...segments]),
      RepoDetail.fromJson,
    );
  }

  /// GETs [url] and parses its JSON object body with [parse], translating
  /// every failure into a [GitHubApiException].
  Future<T> _get<T>(
    Uri url,
    T Function(Map<String, Object?> json) parse,
  ) async {
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
    try {
      // JSON is always UTF-8; `response.body` would fall back to Latin-1
      // when the content-type isn't application/json and has no charset.
      return switch (jsonDecode(utf8.decode(response.bodyBytes))) {
        final Map<String, Object?> json => parse(json),
        final other => throw FormatException('Expected a JSON object', other),
      };
    } on FormatException catch (error) {
      throw MalformedResponseException(error);
    }
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
