import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:github_repo_viewer/data/github/github_api_client.dart';
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
      required List<int> ids,
    }) {
      return http.Response(
        jsonEncode(
          searchJson(
            totalCount: totalCount,
            items: [
              for (final id in ids) repoJson(id: id, fullName: 'owner/r$id'),
            ],
          ),
        ),
        200,
      );
    }

    http.Response rateLimited() => http.Response(
      '{"message": "API rate limit exceeded"}',
      403,
      headers: {'x-ratelimit-remaining': '0'},
    );

    test('loads the first page of results for the query', () async {
      final container = containerWith(
        (_) async => searchResponse(totalCount: 2, ids: [1, 2]),
      );

      final results = await container.read(
        searchResultsProvider('flutter').future,
      );

      expect(requests.single.url.queryParameters, containsPair('q', 'flutter'));
      expect(requests.single.url.queryParameters, containsPair('page', '1'));
      expect(results.items.map((repo) => repo.fullName), [
        'owner/r1',
        'owner/r2',
      ]);
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

      response.complete(searchResponse(totalCount: 1, ids: [1]));
      await container.read(searchResultsProvider('flutter').future);

      expect(subscription.read().value?.items, hasLength(1));
    });

    test('a new query starts loading without the previous results', () async {
      final container = containerWith(
        (request) async => request.url.queryParameters['q'] == 'first'
            ? searchResponse(totalCount: 1, ids: [1])
            : Completer<http.Response>().future,
      );
      container.listen(searchResultsProvider('first'), (_, _) {});
      await container.read(searchResultsProvider('first').future);

      final next = container.listen(searchResultsProvider('second'), (_, _) {});

      expect(next.read(), isA<AsyncLoading<SearchResults>>());
      expect(next.read().hasValue, isFalse);
    });

    group('when the request fails', () {
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
          (_) async =>
              fail ? rateLimited() : searchResponse(totalCount: 1, ids: [1]),
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
        expect(results.items.map((repo) => repo.fullName), ['owner/r1']);
      });
    });

    group('loadNextPage', () {
      /// A container whose search for `flutter` answers page `n` with
      /// `pages[n]`, already showing page 1.
      ///
      /// Pages hold 100 results, so a `total_count` of 200 leaves one more
      /// page after the first.
      Future<ProviderContainer> loadedWith(
        Map<int, Future<http.Response> Function()> pages,
      ) async {
        final container = containerWith(
          (request) =>
              pages[int.parse(request.url.queryParameters['page']!)]!(),
        );
        container.listen(searchResultsProvider('flutter'), (_, _) {});
        await container.read(searchResultsProvider('flutter').future);
        return container;
      }

      SearchResults resultsIn(ProviderContainer container) =>
          container.read(searchResultsProvider('flutter')).requireValue;

      SearchResultsNotifier notifierIn(ProviderContainer container) =>
          container.read(searchResultsProvider('flutter').notifier);

      Iterable<int> idsIn(ProviderContainer container) =>
          resultsIn(container).items.map((repo) => repo.id);

      Future<http.Response> Function() respondWith(
        int totalCount,
        List<int> ids,
      ) =>
          () async => searchResponse(totalCount: totalCount, ids: ids);

      test('appends the next page', () async {
        final container = await loadedWith({
          1: respondWith(200, [1, 2]),
          2: respondWith(200, [3, 4]),
        });

        await notifierIn(container).loadNextPage();

        expect(requests.last.url.queryParameters, containsPair('page', '2'));
        expect(idsIn(container), [1, 2, 3, 4]);
        expect(resultsIn(container).hasMore, isFalse);
      });

      test('is loading more until the page arrives', () async {
        final page2 = Completer<http.Response>();
        final container = await loadedWith({
          1: respondWith(200, [1, 2]),
          2: () => page2.future,
        });

        final loading = notifierIn(container).loadNextPage();

        expect(resultsIn(container).isLoadingMore, isTrue);
        expect(idsIn(container), [1, 2]);

        page2.complete(searchResponse(totalCount: 200, ids: [3, 4]));
        await loading;

        expect(resultsIn(container).isLoadingMore, isFalse);
      });

      test('requests a page only once while it is loading', () async {
        final page2 = Completer<http.Response>();
        final container = await loadedWith({
          1: respondWith(200, [1, 2]),
          2: () => page2.future,
        });

        final first = notifierIn(container).loadNextPage();
        final second = notifierIn(container).loadNextPage();
        page2.complete(searchResponse(totalCount: 200, ids: [3, 4]));
        await Future.wait<void>([first, second]);

        expect(requests, hasLength(2));
        expect(idsIn(container), [1, 2, 3, 4]);
      });

      test('does nothing when there are no more results', () async {
        final container = await loadedWith({
          1: respondWith(2, [1, 2]),
        });

        await notifierIn(container).loadNextPage();

        expect(requests, hasLength(1));
      });

      test('does nothing while the first page is loading', () async {
        final container = containerWith(
          (_) => Completer<http.Response>().future,
        );
        container.listen(searchResultsProvider('flutter'), (_, _) {});

        await notifierIn(container).loadNextPage();
        await Future<void>.delayed(Duration.zero);

        expect(requests.map((request) => request.url.queryParameters['page']), [
          '1',
        ]);
      });

      // The reload replaces the results, so a page of the old ones is stale.
      test('does nothing while the search reloads', () async {
        var reloaded = false;
        final container = await loadedWith({
          1: () => reloaded
              ? Completer<http.Response>().future
              : Future.value(searchResponse(totalCount: 200, ids: [1, 2])),
          2: respondWith(200, [3, 4]),
        });
        reloaded = true;
        container.invalidate(searchResultsProvider('flutter'));
        container.read(searchResultsProvider('flutter'));

        await notifierIn(container).loadNextPage();
        await Future<void>.delayed(Duration.zero);

        expect(requests.map((request) => request.url.queryParameters['page']), [
          '1',
          '1',
        ]);
      });

      // Results can shift between pages while paging, so GitHub may return
      // a repository again.
      test('skips repositories already loaded', () async {
        final container = await loadedWith({
          1: respondWith(200, [1, 2, 3]),
          2: respondWith(200, [3, 4, 5]),
        });

        await notifierIn(container).loadNextPage();

        expect(idsIn(container), [1, 2, 3, 4, 5]);
      });

      group('when the page fails', () {
        Future<ProviderContainer> failedOnPage2() async {
          var page2Fails = true;
          final container = await loadedWith({
            1: respondWith(200, [1, 2]),
            2: () async => page2Fails
                ? rateLimited()
                : searchResponse(totalCount: 200, ids: [3, 4]),
          });
          await notifierIn(container).loadNextPage();
          page2Fails = false;
          return container;
        }

        test('keeps the loaded results and reports the error', () async {
          final container = await failedOnPage2();

          final results = resultsIn(container);
          expect(results.items.map((repo) => repo.id), [1, 2]);
          expect(results.isLoadingMore, isFalse);
          expect(results.loadMoreError, isA<RateLimitException>());
        });

        // Scrolling keeps asking for the next page; only the user retries.
        test('does not request it again until retried', () async {
          final container = await failedOnPage2();

          await notifierIn(container).loadNextPage();

          expect(requests, hasLength(2));
        });

        test('retryNextPage loads it and clears the error', () async {
          final container = await failedOnPage2();

          await notifierIn(container).retryNextPage();

          expect(idsIn(container), [1, 2, 3, 4]);
          expect(resultsIn(container).loadMoreError, isNull);
        });
      });

      test('drops a page that arrives after the search reloaded', () async {
        final page2 = Completer<http.Response>();
        final container = await loadedWith({
          1: respondWith(200, [1, 2]),
          2: () => page2.future,
        });
        final loading = notifierIn(container).loadNextPage();

        container.invalidate(searchResultsProvider('flutter'));
        await container.read(searchResultsProvider('flutter').future);
        page2.complete(searchResponse(totalCount: 200, ids: [3, 4]));
        await loading;

        expect(idsIn(container), [1, 2]);
        expect(resultsIn(container).isLoadingMore, isFalse);
      });
    });

    group('reachedSearchLimit', () {
      /// Loads all 10 pages of a search reporting 5,000 matches, one result
      /// a page, with page 10 holding [lastPage].
      Future<SearchResults> loadAllPages(List<int> lastPage) async {
        final container = containerWith((request) async {
          final page = int.parse(request.url.queryParameters['page']!);
          return searchResponse(
            totalCount: 5000,
            ids: page == GitHubApiClient.maxPage ? lastPage : [page],
          );
        });
        container.listen(searchResultsProvider('flutter'), (_, _) {});
        await container.read(searchResultsProvider('flutter').future);
        final notifier = container.read(
          searchResultsProvider('flutter').notifier,
        );
        for (var page = 2; page <= GitHubApiClient.maxPage; page++) {
          await notifier.loadNextPage();
        }
        return container.read(searchResultsProvider('flutter')).requireValue;
      }

      test('is false while more pages can be loaded', () async {
        final container = containerWith(
          (_) async => searchResponse(totalCount: 5000, ids: [1]),
        );

        final results = await container.read(
          searchResultsProvider('flutter').future,
        );

        expect(results.reachedSearchLimit, isFalse);
      });

      test('is true once the last page has loaded', () async {
        final results = await loadAllPages([10]);

        expect(results.hasMore, isFalse);
        expect(results.reachedSearchLimit, isTrue);
      });

      // total_count can overstate what GitHub returns.
      test('is false when the last page comes back empty', () async {
        final results = await loadAllPages([]);

        expect(results.hasMore, isFalse);
        expect(results.reachedSearchLimit, isFalse);
      });
    });

    test('is disposed when no longer listened to', () async {
      final container = containerWith(
        (_) async => searchResponse(totalCount: 1, ids: [1]),
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
