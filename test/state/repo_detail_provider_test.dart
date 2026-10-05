import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:github_repo_viewer/data/github/github_api_exception.dart';
import 'package:github_repo_viewer/data/github/github_providers.dart';
import 'package:github_repo_viewer/state/repo_detail_provider.dart';

import '../helpers/github_json.dart';

void main() {
  group('repoDetailProvider', () {
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

    http.Response found() => http.Response(
      jsonEncode(
        repoJson(id: 7, fullName: 'flutter/flutter')
          ..['subscribers_count'] = 3500,
      ),
      200,
    );

    http.Response rateLimited() => http.Response(
      '{"message": "API rate limit exceeded"}',
      403,
      headers: {'x-ratelimit-remaining': '0'},
    );

    test('loads the repository by its full name', () async {
      final container = containerWith((_) async => found());

      final detail = await container.read(
        repoDetailProvider('flutter/flutter').future,
      );

      expect(requests.single.url.path, '/repos/flutter/flutter');
      expect(detail.repo.id, 7);
      expect(detail.subscribersCount, 3500);
    });

    test('reports the API error', () async {
      final container = containerWith((_) async => rateLimited());

      await expectLater(
        container.read(repoDetailProvider('flutter/flutter').future),
        throwsA(isA<RateLimitException>()),
      );
    });

    // Unauthenticated clients get 60 requests an hour; the user retries.
    test('does not retry on its own', () async {
      final container = containerWith((_) async => rateLimited());
      container.listen(repoDetailProvider('flutter/flutter'), (_, _) {});
      await container
          .read(repoDetailProvider('flutter/flutter').future)
          .then<void>((_) {}, onError: (Object _) {});

      // Riverpod's default first retry comes after 200ms.
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(requests, hasLength(1));
    });

    test('loads again when invalidated', () async {
      var fail = true;
      final container = containerWith(
        (_) async => fail ? rateLimited() : found(),
      );
      container.listen(repoDetailProvider('flutter/flutter'), (_, _) {});
      await container
          .read(repoDetailProvider('flutter/flutter').future)
          .then<void>((_) {}, onError: (Object _) {});

      fail = false;
      container.invalidate(repoDetailProvider('flutter/flutter'));
      final detail = await container.read(
        repoDetailProvider('flutter/flutter').future,
      );

      expect(requests, hasLength(2));
      expect(detail.subscribersCount, 3500);
    });

    test('is disposed when no longer listened to', () async {
      final container = containerWith((_) async => found());
      final subscription = container.listen(
        repoDetailProvider('flutter/flutter'),
        (_, _) {},
      );
      await container.read(repoDetailProvider('flutter/flutter').future);

      subscription.close();
      await container.pump();

      expect(container.exists(repoDetailProvider('flutter/flutter')), isFalse);
    });
  });
}
