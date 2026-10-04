import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:github_repo_viewer/data/github/github_api_client.dart';
import 'package:github_repo_viewer/data/github/github_api_exception.dart';

import '../../helpers/github_json.dart';

void main() {
  group('GitHubApiClient', () {
    late List<http.Request> requests;

    final now = DateTime.utc(2026, 1, 1, 12);

    /// A client whose HTTP calls all answer [statusCode] with [body] and
    /// [headers], and whose clock is fixed at [now].
    GitHubApiClient clientReturning(
      Object? body, {
      int statusCode = 200,
      Map<String, String> headers = const {},
    }) {
      requests = [];
      return GitHubApiClient(
        MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode(body),
            statusCode,
            headers: {
              'content-type': 'application/json; charset=utf-8',
              ...headers,
            },
          );
        }),
        now: () => now,
      );
    }

    /// Expects GitHub's REST API headers and no credentials.
    void expectGitHubHeaders(http.Request request) {
      expect(request.headers['Accept'], 'application/vnd.github+json');
      expect(request.headers['X-GitHub-Api-Version'], '2022-11-28');
      expect(
        request.headers.keys.map((name) => name.toLowerCase()),
        isNot(contains('authorization')),
      );
    }

    group('searchRepositories', () {
      test('requests the given page of the Search API', () async {
        final client = clientReturning(searchJson(totalCount: 0, items: []));

        await client.searchRepositories('flutter', page: 3);

        final url = requests.single.url;
        expect(url.scheme, 'https');
        expect(url.host, 'api.github.com');
        expect(url.path, '/search/repositories');
        expect(url.queryParameters, {
          'q': 'flutter',
          'page': '3',
          'per_page': '${GitHubApiClient.perPage}',
        });
      });

      test('requests the first page by default', () async {
        final client = clientReturning(searchJson(totalCount: 0, items: []));

        await client.searchRepositories('flutter');

        expect(requests.single.url.queryParameters['page'], '1');
      });

      test('encodes the query', () async {
        final client = clientReturning(searchJson(totalCount: 0, items: []));

        await client.searchRepositories('state management & c++');

        final url = requests.single.url;
        expect(url.queryParameters['q'], 'state management & c++');
        expect(url.query, isNot(contains(' ')));
      });

      test('sends GitHub API headers and no Authorization', () async {
        final client = clientReturning(searchJson(totalCount: 0, items: []));

        await client.searchRepositories('flutter');

        expectGitHubHeaders(requests.single);
      });

      test('returns the parsed page', () async {
        final client = clientReturning(
          searchJson(
            totalCount: 300,
            items: [
              repoJson(id: 1, fullName: 'a/one'),
              repoJson(id: 2, fullName: 'b/two'),
            ],
          ),
        );

        final page = await client.searchRepositories('flutter');

        expect(page.items.map((repo) => repo.fullName), ['a/one', 'b/two']);
        expect(page.totalCount, 300);
        expect(page.hasMore, isTrue);
      });

      // GitHub rejects an empty q with 422; the UI shows its home state
      // instead of searching.
      test('rejects a blank query without a request', () async {
        final client = clientReturning(searchJson(totalCount: 0, items: []));

        await expectLater(
          client.searchRepositories('   '),
          throwsArgumentError,
        );
        expect(requests, isEmpty);
      });
    });

    group('searchRepositories page bounds', () {
      // The most GitHub allows; fewer pages mean fewer of the 10 searches a
      // minute spent on scrolling.
      test('asks for 100 results a page', () {
        expect(GitHubApiClient.perPage, 100);
      });

      // 1000 results / 100 per page: page 10 holds results 901–1000.
      test('allows pages 1 to ${GitHubApiClient.maxPage}', () async {
        expect(GitHubApiClient.maxPage, 10);
        final client = clientReturning(searchJson(totalCount: 0, items: []));

        await client.searchRepositories('flutter', page: 1);
        await client.searchRepositories('flutter', page: 10);

        expect(requests, hasLength(2));
      });

      for (final page in [-1, 0, 11]) {
        test('rejects page $page without a request', () async {
          final client = clientReturning(searchJson(totalCount: 0, items: []));

          await expectLater(
            client.searchRepositories('flutter', page: page),
            throwsA(isA<RangeError>()),
          );
          expect(requests, isEmpty);
        });
      }
    });

    group('fetchRepository', () {
      Map<String, Object?> detailJson() =>
          repoJson(id: 7, fullName: 'flutter/flutter')
            ..['subscribers_count'] = 3500;

      test('requests the Repository API for full_name', () async {
        final client = clientReturning(detailJson());

        await client.fetchRepository('flutter/flutter');

        final request = requests.single;
        expect(request.method, 'GET');
        expect(
          request.url,
          Uri.parse('https://api.github.com/repos/flutter/flutter'),
        );
        expectGitHubHeaders(request);
      });

      test('returns the parsed repository detail', () async {
        final client = clientReturning(detailJson());

        final detail = await client.fetchRepository('flutter/flutter');

        expect(detail.repo.id, 7);
        expect(detail.repo.fullName, 'flutter/flutter');
        expect(detail.subscribersCount, 3500);
      });

      for (final fullName in ['flutter', 'flutter/', '/flutter', 'a/b/c']) {
        test('rejects "$fullName" without a request', () async {
          final client = clientReturning(detailJson());

          await expectLater(
            client.fetchRepository(fullName),
            throwsArgumentError,
          );
          expect(requests, isEmpty);
        });
      }
    });

    // https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api#exceeding-the-rate-limit
    group('rate limiting', () {
      Future<Object?> searchError(GitHubApiClient client) async {
        try {
          await client.searchRepositories('flutter');
        } catch (error) {
          return error;
        }
        fail('expected searchRepositories to throw');
      }

      test('throws RateLimitException until x-ratelimit-reset', () async {
        final resetAt = now.add(const Duration(minutes: 30));
        final client = clientReturning(
          {'message': 'API rate limit exceeded for 203.0.113.1.'},
          statusCode: 403,
          headers: {
            'x-ratelimit-remaining': '0',
            'x-ratelimit-reset': '${resetAt.millisecondsSinceEpoch ~/ 1000}',
          },
        );

        final error = await searchError(client);

        expect(error, isA<RateLimitException>());
        expect((error! as RateLimitException).retryAt, resetAt);
      });

      test('throws RateLimitException until retry-after elapses', () async {
        final client = clientReturning(
          {'message': 'You have exceeded a secondary rate limit.'},
          statusCode: 429,
          headers: {'retry-after': '60'},
        );

        final error = await searchError(client);

        expect(error, isA<RateLimitException>());
        expect(
          (error! as RateLimitException).retryAt,
          now.add(const Duration(seconds: 60)),
        );
      });

      test('prefers retry-after over x-ratelimit-reset', () async {
        final client = clientReturning(
          {'message': 'You have exceeded a secondary rate limit.'},
          statusCode: 403,
          headers: {
            'retry-after': '60',
            'x-ratelimit-remaining': '0',
            'x-ratelimit-reset': '${now.millisecondsSinceEpoch ~/ 1000 + 3600}',
          },
        );

        final error = await searchError(client);

        expect(
          (error! as RateLimitException).retryAt,
          now.add(const Duration(seconds: 60)),
        );
      });

      // Secondary rate limits may come without retry-after or a zero
      // remaining count; only the message tells them apart.
      test('recognizes a secondary rate limit by its message', () async {
        final client = clientReturning(
          {'message': 'You have exceeded a secondary rate limit.'},
          statusCode: 403,
          headers: {'x-ratelimit-remaining': '42'},
        );

        final error = await searchError(client);

        expect(error, isA<RateLimitException>());
        expect((error! as RateLimitException).retryAt, isNull);
      });

      test('treats any 429 as a rate limit', () async {
        final client = clientReturning({}, statusCode: 429);

        expect(await searchError(client), isA<RateLimitException>());
      });

      test('applies to fetchRepository too', () async {
        final client = clientReturning(
          {'message': 'API rate limit exceeded.'},
          statusCode: 403,
          headers: {'x-ratelimit-remaining': '0'},
        );

        await expectLater(
          client.fetchRepository('flutter/flutter'),
          throwsA(isA<RateLimitException>()),
        );
      });
    });

    group('HTTP errors', () {
      test('throws NotFoundException for 404', () async {
        final client = clientReturning({
          'message': 'Not Found',
        }, statusCode: 404);

        await expectLater(
          client.fetchRepository('flutter/deleted'),
          throwsA(isA<NotFoundException>()),
        );
      });

      // 403 also means "forbidden", e.g. a repository blocked for legal
      // reasons; only rate limiting is reported as RateLimitException.
      test('throws HttpStatusException for a 403 that is not a rate limit', () {
        final client = clientReturning(
          {'message': 'Repository access blocked'},
          statusCode: 403,
          headers: {'x-ratelimit-remaining': '42'},
        );

        expect(
          client.fetchRepository('owner/blocked'),
          throwsA(
            isA<HttpStatusException>().having(
              (e) => e.statusCode,
              'statusCode',
              403,
            ),
          ),
        );
      });

      for (final statusCode in [422, 500, 503]) {
        test('throws HttpStatusException for $statusCode', () {
          final client = clientReturning({
            'message': 'error',
          }, statusCode: statusCode);

          expect(
            client.searchRepositories('flutter'),
            throwsA(
              isA<HttpStatusException>().having(
                (e) => e.statusCode,
                'statusCode',
                statusCode,
              ),
            ),
          );
        });
      }
    });

    group('network errors', () {
      test('throws NetworkException when the request fails', () async {
        final cause = http.ClientException('Connection refused');
        final client = GitHubApiClient(
          MockClient((request) async => throw cause),
        );

        await expectLater(
          client.searchRepositories('flutter'),
          throwsA(
            isA<NetworkException>().having((e) => e.cause, 'cause', cause),
          ),
        );
      });

      // http wraps socket errors in ClientException but lets TLS errors
      // through, e.g. when a captive portal intercepts HTTPS.
      test('throws NetworkException when the TLS handshake fails', () async {
        final client = GitHubApiClient(
          MockClient((request) async => throw const HandshakeException()),
        );

        await expectLater(
          client.searchRepositories('flutter'),
          throwsA(
            isA<NetworkException>().having(
              (e) => e.cause,
              'cause',
              isA<HandshakeException>(),
            ),
          ),
        );
      });

      test('throws NetworkException when the request times out', () async {
        final client = GitHubApiClient(
          MockClient((request) => Completer<http.Response>().future),
          timeout: const Duration(milliseconds: 10),
        );

        await expectLater(
          client.fetchRepository('flutter/flutter'),
          throwsA(
            isA<NetworkException>().having(
              (e) => e.cause,
              'cause',
              isA<TimeoutException>(),
            ),
          ),
        );
      });
    });

    group('malformed responses', () {
      GitHubApiClient clientReturningRaw(String body) {
        return GitHubApiClient(
          MockClient((request) async => http.Response(body, 200)),
        );
      }

      final isMalformed = throwsA(
        isA<MalformedResponseException>().having(
          (e) => e.cause,
          'cause',
          isA<FormatException>(),
        ),
      );

      // e.g. an HTML error page from a proxy or captive portal.
      test('throws MalformedResponseException when the body is not JSON', () {
        final client = clientReturningRaw('<html>Sign in to Wi-Fi</html>');

        expect(client.searchRepositories('flutter'), isMalformed);
      });

      test('throws MalformedResponseException when the body is not an '
          'object', () {
        final client = clientReturningRaw('[]');

        expect(client.fetchRepository('flutter/flutter'), isMalformed);
      });

      test('throws MalformedResponseException for an invalid search '
          'response', () {
        final client = clientReturning({'total_count': 1});

        expect(client.searchRepositories('flutter'), isMalformed);
      });

      test('throws MalformedResponseException for an invalid repository', () {
        final client = clientReturning(repoJson());

        expect(client.fetchRepository('owner/repo'), isMalformed);
      });
    });

    // JSON is always UTF-8 (RFC 8259). package:http assumes that only for
    // an application/json content-type; otherwise, e.g. when a proxy drops
    // the header, it decodes without a charset as Latin-1.
    group('response encoding', () {
      GitHubApiClient clientReturningBytes(List<int> body) {
        return GitHubApiClient(
          MockClient((request) async => http.Response.bytes(body, 200)),
        );
      }

      test('reads the body as UTF-8 without a content-type', () async {
        final client = clientReturningBytes(
          utf8.encode(
            jsonEncode({
              ...repoJson(fullName: 'owner/café'),
              'subscribers_count': 1,
            }),
          ),
        );

        final detail = await client.fetchRepository('owner/repo');

        expect(detail.repo.fullName, 'owner/café');
      });

      test('throws MalformedResponseException for invalid UTF-8', () {
        final client = clientReturningBytes([0x7b, 0xff, 0x7d]);

        expect(
          client.fetchRepository('owner/repo'),
          throwsA(isA<MalformedResponseException>()),
        );
      });
    });
  });
}
