import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:github_repo_viewer/data/github/github_providers.dart';
import 'package:github_repo_viewer/data/preferences/shared_preferences_provider.dart';
import 'package:github_repo_viewer/ui/search/search_results_list.dart';
import 'package:github_repo_viewer/ui/search/search_results_view.dart';

import '../../helpers/avatars.dart';
import '../../helpers/github_json.dart';
import '../../helpers/preferences.dart';

void main() {
  group('SearchResultsView', () {
    late int requestCount;

    /// Shows the results for `flutter`, answering each search with
    /// [respond].
    Future<void> pumpView(
      WidgetTester tester,
      Future<http.Response> Function(http.Request request) respond,
    ) async {
      requestCount = 0;
      final preferences = await inMemoryPreferences();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            AvatarFixtures().override,
            sharedPreferencesProvider.overrideWithValue(preferences),
            httpClientProvider.overrideWithValue(
              MockClient((request) {
                requestCount++;
                return respond(request);
              }),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SearchResultsView(query: 'flutter', onRepoTap: (_) {}),
            ),
          ),
        ),
      );
    }

    http.Response found(int count, {int? totalCount, int firstId = 1}) =>
        http.Response(
          jsonEncode(
            searchJson(
              totalCount: totalCount ?? count,
              items: [
                for (var id = firstId; id < firstId + count; id++)
                  repoJson(id: id, fullName: 'owner/r$id'),
              ],
            ),
          ),
          200,
        );

    http.Response rateLimited() => http.Response(
      '{"message": "API rate limit exceeded"}',
      403,
      headers: {'x-ratelimit-remaining': '0'},
    );

    final spinner = find.byType(CircularProgressIndicator);

    testWidgets('shows a loading indicator while searching', (tester) async {
      final response = Completer<http.Response>();
      await pumpView(tester, (_) => response.future);

      expect(spinner, findsOneWidget);

      response.complete(found(1));
      await tester.pump();

      expect(spinner, findsNothing);
    });

    testWidgets(
      "uses the platform's loading indicator",
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      (tester) async {
        final response = Completer<http.Response>();
        await pumpView(tester, (_) => response.future);

        expect(find.byType(CupertinoActivityIndicator), findsOneWidget);

        response.complete(found(1));
        await tester.pump();
      },
    );

    testWidgets('lists the results', (tester) async {
      await pumpView(tester, (_) async => found(2));
      await tester.pump();

      expect(find.byType(SearchResultsList), findsOneWidget);
      expect(find.text('owner/r1'), findsOneWidget);
    });

    testWidgets('says when nothing matches', (tester) async {
      await pumpView(tester, (_) async => found(0));
      await tester.pump();

      expect(find.text('No results'), findsOneWidget);
      expect(find.textContaining('"flutter"'), findsOneWidget);
      expect(find.byType(SearchResultsList), findsNothing);
    });

    group('when the search fails', () {
      testWidgets('describes the error', (tester) async {
        await pumpView(tester, (_) async => rateLimited());
        await tester.pump();

        expect(find.text('Too many requests'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
      });

      testWidgets('searches again on retry', (tester) async {
        var fail = true;
        final retried = Completer<http.Response>();
        await pumpView(
          tester,
          (_) => fail ? Future.value(rateLimited()) : retried.future,
        );
        await tester.pump();
        fail = false;

        await tester.tap(find.text('Retry'));
        await tester.pump();

        expect(requestCount, 2);
        // The old error is replaced by a loading indicator straight away.
        expect(spinner, findsOneWidget);
        expect(find.text('Too many requests'), findsNothing);

        retried.complete(found(1));
        await tester.pump();

        expect(find.text('owner/r1'), findsOneWidget);
      });
    });

    testWidgets('loads the next page when scrolled near the end', (
      tester,
    ) async {
      await pumpView(
        tester,
        (request) async => request.url.queryParameters['page'] == '1'
            ? found(100, totalCount: 200)
            : found(100, totalCount: 200, firstId: 101),
      );
      await tester.pump();

      expect(requestCount, 1);

      await tester.scrollUntilVisible(find.text('owner/r60'), 500);
      await tester.pump();
      await tester.pump();

      expect(requestCount, 2);
      await tester.scrollUntilVisible(find.text('owner/r200'), 500);
      expect(find.text('owner/r200'), findsOneWidget);
    });

    testWidgets('retries a page that failed to load', (tester) async {
      var page2Fails = true;
      await pumpView(tester, (request) async {
        if (request.url.queryParameters['page'] == '1') {
          return found(3, totalCount: 200);
        }
        return page2Fails
            ? rateLimited()
            : found(3, totalCount: 200, firstId: 101);
      });
      await tester.pump();
      await tester.pump();
      page2Fails = false;

      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(requestCount, 3);
      expect(find.text('owner/r101'), findsOneWidget);
    });
  });
}
