import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:github_repo_viewer/data/github/github_api_client.dart';

import '../../helpers/github_json.dart';

void main() {
  group('GitHubApiClient', () {
    late List<http.Request> requests;

    /// A client whose HTTP calls all answer [statusCode] with [body].
    GitHubApiClient clientReturning(Object? body, {int statusCode = 200}) {
      requests = [];
      return GitHubApiClient(
        MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode(body),
            statusCode,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
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
            totalCount: 100,
            items: [
              repoJson(id: 1, fullName: 'a/one'),
              repoJson(id: 2, fullName: 'b/two'),
            ],
          ),
        );

        final page = await client.searchRepositories('flutter');

        expect(page.items.map((repo) => repo.fullName), ['a/one', 'b/two']);
        expect(page.totalCount, 100);
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
  });
}
