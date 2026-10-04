import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:github_repo_viewer/data/github/github_providers.dart';

import '../../helpers/github_json.dart';

void main() {
  group('httpClientProvider', () {
    test('closes the client when the container is disposed', () async {
      final container = ProviderContainer();
      final client = container.read(httpClientProvider);

      container.dispose();

      // A closed client fails before opening a connection.
      await expectLater(
        client.get(Uri.https('api.github.com', '/')),
        throwsA(
          isA<http.ClientException>().having(
            (e) => e.message,
            'message',
            contains('closed'),
          ),
        ),
      );
    });
  });

  group('gitHubApiClientProvider', () {
    test('sends requests through httpClientProvider', () async {
      final requests = <http.Request>[];
      final container = ProviderContainer.test(
        overrides: [
          httpClientProvider.overrideWithValue(
            MockClient((request) async {
              requests.add(request);
              return http.Response(
                jsonEncode(searchJson(totalCount: 0, items: [])),
                200,
              );
            }),
          ),
        ],
      );

      await container
          .read(gitHubApiClientProvider)
          .searchRepositories('flutter');

      expect(requests.single.url.path, '/search/repositories');
    });

    test('is shared within a container', () {
      final container = ProviderContainer.test();

      expect(
        container.read(gitHubApiClientProvider),
        same(container.read(gitHubApiClientProvider)),
      );
    });
  });
}
