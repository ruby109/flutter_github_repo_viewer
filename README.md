# GitHub Repo Viewer

[![CI](https://github.com/ruby109/flutter_github_repo_viewer/actions/workflows/ci.yml/badge.svg)](https://github.com/ruby109/flutter_github_repo_viewer/actions/workflows/ci.yml)

A Flutter app for iOS and Android that searches GitHub repositories and keeps a list of the ones you star.

- **Search**: find public repositories through the GitHub REST API.
- **Stars**: save repositories locally and browse them later, offline.

## Tech Stack

| Concern | Choice |
|---|---|
| State management | [hooks_riverpod](https://pub.dev/packages/hooks_riverpod) + [flutter_hooks](https://pub.dev/packages/flutter_hooks) |
| Networking | [http](https://pub.dev/packages/http) |
| Local persistence | [shared_preferences](https://pub.dev/packages/shared_preferences) |
| Linting | [flutter_lints](https://pub.dev/packages/flutter_lints), [riverpod_lint](https://pub.dev/packages/riverpod_lint), strict analyzer modes |

## Requirements

- Flutter 3.47 (stable channel) with Dart 3.13
- Xcode for the iOS simulator, Android Studio (or the Android SDK) for the Android emulator

## Getting Started

```sh
git clone https://github.com/ruby109/flutter_github_repo_viewer.git
cd flutter_github_repo_viewer
flutter pub get
flutter run            # pick a simulator/emulator, or pass -d <device-id>
```

## GitHub API

The app calls two public endpoints of the [GitHub REST API](https://docs.github.com/en/rest) through `GitHubApiClient` (`lib/data/github/`). Requests are unauthenticated, so there is no token to configure. Every request sends `Accept: application/vnd.github+json` and `X-GitHub-Api-Version: 2022-11-28` and times out after 15 seconds.

### Search repositories

[`GET /search/repositories`](https://docs.github.com/en/rest/search/search#search-repositories): `searchRepositories(query, page:)` returns a `SearchPage`.

| Parameter | Value |
|---|---|
| `q` | The search box text. A blank query is rejected before sending, since GitHub answers it with 422; the screen shows its home state instead. |
| `page` | 1 to 34. Pages past the 1000-result limit are rejected before sending. |
| `per_page` | 30 |

Fields used from each item (`GitHubRepo`):

| JSON | Dart | Notes |
|---|---|---|
| `id` | `id` | Identifies a starred repository |
| `full_name` | `fullName` | `owner/name` |
| `owner.avatar_url` | `owner?.avatarUrl` | GitHub documents `owner` as nullable |

`SearchPage.hasMore` controls infinite scrolling. It is false on the last page, on an empty page, and after 1000 results: the Search API returns at most 1000 results per query, however large `total_count` is, and later pages fail with 422.

### Get a repository

[`GET /repos/{owner}/{repo}`](https://docs.github.com/en/rest/repos/repos#get-a-repository): `fetchRepository(fullName)` returns a `RepoDetail`, which holds the same `GitHubRepo` fields plus `subscribers_count` (`subscribersCount`), a field search results don't include.

### Errors

Every failure is a subclass of the sealed `GitHubApiException`, so screens can `switch` over all of them:

| Exception | When |
|---|---|
| `RateLimitException` | 429, or 403 with `retry-after`, `x-ratelimit-remaining: 0` or a rate limit message. `retryAt` comes from `retry-after` or `x-ratelimit-reset` when GitHub sends them. |
| `NotFoundException` | 404, e.g. a repository deleted after it was listed |
| `HttpStatusException` | Any other non-2xx status, including a 403 that isn't rate limiting |
| `NetworkException` | No connection, a dropped connection, a TLS failure, or a timeout |
| `MalformedResponseException` | A 2xx body that isn't JSON or lacks required fields |

Unauthenticated clients get [10 searches a minute](https://docs.github.com/en/rest/search/search#rate-limit) and [60 other requests an hour](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api#primary-rate-limit-for-unauthenticated-users) per IP address, so rate limiting is an expected state, not an edge case.

### Using the client and testing with it

`gitHubApiClientProvider` provides the client, built on `httpClientProvider`, which closes the `http.Client` when its container is disposed. Tests override either provider instead of touching the network; the API tests use `MockClient` from `package:http/testing.dart`, which ships with `http`:

```dart
ProviderScope(
  overrides: [
    httpClientProvider.overrideWithValue(
      MockClient((request) async => http.Response('{"total_count":0,"items":[]}', 200)),
    ),
  ],
  child: const MyApp(),
);
```

## Development Setup

Git hooks that format, analyze and test your changes, and check commit messages, are managed by [lefthook](https://lefthook.dev):

```sh
brew install lefthook
lefthook install
```

See [AGENTS.md](AGENTS.md) for exactly what each hook runs.

## Testing

```sh
flutter test --exclude-tags golden    # unit and widget tests
```

CI runs the same format, analyze and test checks on every push to `main` and on pull requests.

Golden (snapshot) tests render key screens at iPhone 17, iPhone SE, iPad and Android phone sizes. They run on Linux CI for every pull request; to regenerate the golden files after an intended UI change, push the branch and run:

```sh
scripts/update-goldens.sh
```

## Contributing

Commit conventions and other rules for contributors (human or AI agent) are in [AGENTS.md](AGENTS.md).
