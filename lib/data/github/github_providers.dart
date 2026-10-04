import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;

import 'github_api_client.dart';

/// The HTTP client for GitHub API calls; closed with its container.
///
/// Override it with a `MockClient` (from `package:http/testing.dart`) to
/// test anything that calls GitHub without network access.
final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// The GitHub API client the app's providers use.
final gitHubApiClientProvider = Provider<GitHubApiClient>(
  (ref) => GitHubApiClient(ref.watch(httpClientProvider)),
);
