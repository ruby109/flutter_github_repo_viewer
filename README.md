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
| Testing | [shared_preferences_platform_interface](https://pub.dev/packages/shared_preferences_platform_interface) (dev only, for its in-memory store; see [Favorites](#testing-favorites)) |
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

## Favorites

Starred repositories are stored on the device with `shared_preferences`. GitHub's own starring API isn't used, so no account is needed. The code is in `lib/state/favorites_notifier.dart`.

### Storage

All favorites are stored under one key, `favorites`, as a JSON array of the fields the app shows:

```json
[
  {"id": 2, "full_name": "dart-lang/sdk", "owner": null},
  {"id": 1, "full_name": "flutter/flutter", "owner": {"avatar_url": "https://avatars.githubusercontent.com/u/14101776?v=4"}}
]
```

- Entries use the GitHub API's own field names and are read back with `GitHubRepo.fromJson`, so the API and storage share one parser.
- The list is ordered most recently starred first. The assignment doesn't specify an order. The array keeps the order, so no timestamp is stored.
- Every change rewrites the whole array. shared_preferences can only replace a key's whole value, and one write always stores one complete list.
- `main()` loads the preferences (`SharedPreferencesWithCache`, limited to the `favorites` key) before `runApp`, and injects them through `sharedPreferencesProvider`. From then on favorites are read synchronously, so no screen has a loading state for them.

### Keeping screens in sync

`favoritesProvider` (`FavoritesNotifier`) is the only owner of the starred list. Every screen reads from it and stars through `toggle(repo)`, which matches repositories by `id`. The change shows on every screen immediately, before it is saved.

| Provider | Use |
|---|---|
| `favoritesProvider` | The starred list, for the Stars tab, and `toggle` |
| `isStarredProvider(id)` | Whether one repository is starred, for a star icon |

`isStarredProvider` is an `autoDispose` family over a set of starred ids:

- **Narrow rebuilds.** It notifies only when that repository's star changes, so starring one row doesn't rebuild the others.
- **Bounded memory.** It is disposed when a row scrolls away, so ids from long search results don't accumulate.

### Corrupt data and failed saves

- **Unreadable stored data** (not JSON, not an array, or the wrong type) loads as no favorites instead of crashing. Invalid entries and duplicate ids are skipped, and the valid entries are kept. The bad data is replaced on the next change.
- **Failed saves.** If a save fails, `toggle` throws so the UI can tell the user. Once no other save is pending, the notifier reloads what is actually stored and shows that. It doesn't undo just the failed change, because a later save writes the whole list and may already contain it.

### Testing favorites

Tests replace the platform store with `InMemorySharedPreferencesAsync` from [shared_preferences_platform_interface](https://pub.dev/packages/shared_preferences_platform_interface). It is shared_preferences' own platform package and already a transitive dependency. It is listed as a dev dependency only so tests can import it, and it isn't part of the app. `test/helpers/preferences.dart` also has a store whose writes and reads a test can hold, fail or complete in any order, to cover concurrent saves.

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
