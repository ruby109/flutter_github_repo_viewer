import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:github_repo_viewer/data/github/github_api_exception.dart';
import 'package:github_repo_viewer/data/github/github_providers.dart';
import 'package:github_repo_viewer/state/search_results_notifier.dart';

import '../helpers/github_json.dart';

void main() {
  group('SearchResultsNotifier', () {
    late List<http.Request> requests;

    /// A container whose GitHub API answers every request with [respond].
    ProviderContainer containerWith(
      Future<http.Response> Function(http.Request request) respond,
    ) {
      requests = [];
      return ProviderContainer.test(
        overrides: [
          httpClientProvider.overrideWithValue(
            MockClient((request) {
              requests.add(request);
              return respond(request);
            }),
          ),
        ],
      );
    }

    http.Response searchResponse({
      required int totalCount,
      required List<String> fullNames,
    }) {
      return http.Response(
        jsonEncode(
          searchJson(
            totalCount: totalCount,
            items: [
              for (final (index, fullName) in fullNames.indexed)
                repoJson(id: index + 1, fullName: fullName),
            ],
          ),
        ),
        200,
      );
    }

    test('loads the first page of results for the query', () async {
      final container = containerWith(
        (_) async =>
            searchResponse(totalCount: 2, fullNames: ['a/one', 'b/two']),
      );

      final results = await container.read(
        searchResultsProvider('flutter').future,
      );

      expect(requests.single.url.queryParameters, containsPair('q', 'flutter'));
      expect(requests.single.url.queryParameters, containsPair('page', '1'));
      expect(results.items.map((repo) => repo.fullName), ['a/one', 'b/two']);
      expect(results.totalCount, 2);
      expect(results.hasMore, isFalse);
    });

    test('is loading until the first page arrives', () async {
      final response = Completer<http.Response>();
      final container = containerWith((_) => response.future);
      final subscription = container.listen(
        searchResultsProvider('flutter'),
        (_, _) {},
      );

      expect(subscription.read(), isA<AsyncLoading<SearchResults>>());

      response.complete(searchResponse(totalCount: 1, fullNames: ['a/one']));
      await container.read(searchResultsProvider('flutter').future);

      expect(subscription.read().value?.items, hasLength(1));
    });

    test('a new query starts loading without the previous results', () async {
      final container = containerWith(
        (request) async => request.url.queryParameters['q'] == 'first'
            ? searchResponse(totalCount: 1, fullNames: ['a/one'])
            : Completer<http.Response>().future,
      );
      container.listen(searchResultsProvider('first'), (_, _) {});
      await container.read(searchResultsProvider('first').future);

      final next = container.listen(searchResultsProvider('second'), (_, _) {});

      expect(next.read(), isA<AsyncLoading<SearchResults>>());
      expect(next.read().hasValue, isFalse);
    });

    group('when the request fails', () {
      http.Response rateLimited() => http.Response(
        '{"message": "API rate limit exceeded"}',
        403,
        headers: {'x-ratelimit-remaining': '0'},
      );

      test('reports the API error', () async {
        final container = containerWith((_) async => rateLimited());

        await expectLater(
          container.read(searchResultsProvider('flutter').future),
          throwsA(isA<RateLimitException>()),
        );
      });

      // Unauthenticated clients get 10 searches a minute, so automatic
      // retries would use them up; the user retries instead.
      test('does not retry on its own', () async {
        final container = containerWith((_) async => rateLimited());
        container.listen(searchResultsProvider('flutter'), (_, _) {});
        await container
            .read(searchResultsProvider('flutter').future)
            .catchError((Object _) => const SearchResults.empty());

        // Riverpod's default first retry comes after 200ms.
        await Future<void>.delayed(const Duration(milliseconds: 500));

        expect(requests, hasLength(1));
      });

      test('loads again when invalidated', () async {
        var fail = true;
        final container = containerWith(
          (_) async => fail
              ? rateLimited()
              : searchResponse(totalCount: 1, fullNames: ['a/one']),
        );
        container.listen(searchResultsProvider('flutter'), (_, _) {});
        await container
            .read(searchResultsProvider('flutter').future)
            .catchError((Object _) => const SearchResults.empty());

        fail = false;
        container.invalidate(searchResultsProvider('flutter'));
        final results = await container.read(
          searchResultsProvider('flutter').future,
        );

        expect(requests, hasLength(2));
        expect(results.items.map((repo) => repo.fullName), ['a/one']);
      });
    });

    test('is disposed when no longer listened to', () async {
      final container = containerWith(
        (_) async => searchResponse(totalCount: 1, fullNames: ['a/one']),
      );
      final subscription = container.listen(
        searchResultsProvider('flutter'),
        (_, _) {},
      );
      await container.read(searchResultsProvider('flutter').future);

      subscription.close();
      await container.pump();

      expect(container.exists(searchResultsProvider('flutter')), isFalse);
    });
  });
}
