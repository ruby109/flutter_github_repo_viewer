import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:github_repo_viewer/data/github/github_providers.dart';
import 'package:github_repo_viewer/data/github/github_repo.dart';
import 'package:github_repo_viewer/data/preferences/shared_preferences_provider.dart';
import 'package:github_repo_viewer/ui/common/repo_avatar.dart';
import 'package:github_repo_viewer/ui/common/star_button.dart';
import 'package:github_repo_viewer/ui/detail/repo_detail_screen.dart';

import '../../helpers/github_json.dart';
import '../../helpers/preferences.dart';

void main() {
  group('RepoDetailScreen', () {
    const repo = GitHubRepo(
      id: 7,
      fullName: 'flutter/flutter',
      owner: Owner(avatarUrl: 'https://example.com/a.png'),
    );

    late int requestCount;

    /// Shows [repo], answering the Repository API with [respond].
    Future<void> pumpScreen(
      WidgetTester tester,
      Future<http.Response> Function() respond, {
      GitHubRepo shown = repo,
    }) async {
      requestCount = 0;
      final preferences = await inMemoryPreferences();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            httpClientProvider.overrideWithValue(
              MockClient((_) {
                requestCount++;
                return respond();
              }),
            ),
          ],
          child: MaterialApp(home: RepoDetailScreen(repo: shown)),
        ),
      );
    }

    http.Response found({int subscribers = 3546}) => http.Response(
      jsonEncode(
        repoJson(id: 7, fullName: 'flutter/flutter')
          ..['subscribers_count'] = subscribers,
      ),
      200,
    );

    http.Response rateLimited() => http.Response(
      '{"message": "API rate limit exceeded"}',
      403,
      headers: {'x-ratelimit-remaining': '0'},
    );

    final spinner = find.byType(CircularProgressIndicator);

    // The list already has these, so they show without waiting.
    testWidgets('shows the name, avatar and star right away', (tester) async {
      final response = Completer<http.Response>();
      await pumpScreen(tester, () => response.future);

      expect(find.text('flutter/flutter'), findsOneWidget);
      expect(
        tester.widget<RepoAvatar>(find.byType(RepoAvatar)).url,
        'https://example.com/a.png',
      );
      expect(tester.widget<StarButton>(find.byType(StarButton)).repo.id, 7);

      response.complete(found());
      await tester.pump();
    });

    testWidgets('loads the subscriber count', (tester) async {
      final response = Completer<http.Response>();
      await pumpScreen(tester, () => response.future);

      expect(spinner, findsOneWidget);

      response.complete(found());
      await tester.pump();

      expect(spinner, findsNothing);
      expect(find.text('3,546'), findsOneWidget);
      expect(find.text('Subscribers'), findsOneWidget);
    });

    group('formats the subscriber count', () {
      const cases = {0: '0', 999: '999', 1000: '1,000', 1234567: '1,234,567'};

      cases.forEach((count, text) {
        testWidgets('$count as $text', (tester) async {
          await pumpScreen(tester, () async => found(subscribers: count));
          await tester.pump();

          expect(find.text(text), findsOneWidget);
        });
      });
    });

    group('when loading fails', () {
      testWidgets('describes the error', (tester) async {
        await pumpScreen(tester, () async => rateLimited());
        await tester.pump();

        expect(find.textContaining('Wait a minute'), findsOneWidget);
        // The rest of the screen stays usable.
        expect(find.text('flutter/flutter'), findsOneWidget);
        expect(find.byType(StarButton), findsOneWidget);
      });

      testWidgets('loads again on retry', (tester) async {
        var fail = true;
        final retried = Completer<http.Response>();
        await pumpScreen(
          tester,
          () => fail ? Future.value(rateLimited()) : retried.future,
        );
        await tester.pump();
        fail = false;

        await tester.tap(find.text('Retry'));
        await tester.pump();

        expect(requestCount, 2);
        // The old error is replaced by a loading indicator straight away.
        expect(spinner, findsOneWidget);
        expect(find.textContaining('Wait a minute'), findsNothing);

        retried.complete(found());
        await tester.pump();

        expect(find.text('3,546'), findsOneWidget);
      });

      // Retrying can't bring back a deleted repository.
      testWidgets('offers no retry when the repository is gone', (
        tester,
      ) async {
        await pumpScreen(tester, () async => http.Response('{}', 404));
        await tester.pump();

        expect(find.text('This repository no longer exists.'), findsOneWidget);
        expect(find.text('Retry'), findsNothing);
      });
    });

    testWidgets('fits a long name', (tester) async {
      await pumpScreen(
        tester,
        () async => found(),
        shown: GitHubRepo(id: 7, fullName: 'owner/${'a' * 300}', owner: null),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
