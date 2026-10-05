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

The app calls two public endpoints of the [GitHub REST API](https://docs.github.com/en/rest) through `GitHubApiClient` (`lib/data/github/`). Requests are unauthenticated, so there is no token to configure. Every request sends `Accept: application/vnd.github+json` and `X-GitHub-Api-Version: 2022-11-28` and times out after 15 seconds. Response bodies are decoded as UTF-8, as JSON requires, whatever the `content-type` header says.

### Search repositories

[`GET /search/repositories`](https://docs.github.com/en/rest/search/search#search-repositories): `searchRepositories(query, page:)` returns a `SearchPage`.

| Parameter | Value |
|---|---|
| `q` | The search box text. A blank query is rejected before sending, since GitHub answers it with 422; the screen shows its home state instead. |
| `page` | 1 to 10. Pages past the 1000-result limit are rejected before sending. |
| `per_page` | 100, the most GitHub allows, so scrolling spends as few of the 10 searches a minute as possible |

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

## Search Screen

The Search tab (`lib/ui/search/`) searches repositories by keyword. Its state is in `lib/state/search_query_notifier.dart` and `lib/state/search_results_notifier.dart`.

### States

| State | When |
|---|---|
| Home | The search box is empty or blank. Deleting the text returns here at once. |
| Loading | The first page of a search is loading, or a failed search is being retried. |
| Results | Each row shows the owner avatar, `full_name` and a star button. Tapping a row opens its [details](#detail-screen). |
| No results | GitHub found nothing for the keyword. |
| Error | The search failed. The message comes from the error type (no connection, rate limited, ...), with a Retry button. When rate limited, it says when to try again if GitHub sent a time. |

### When it searches

- **Only when the keyboard's search key is pressed**, not while typing. Unauthenticated clients get 10 searches a minute, which typing would use up in a few words.
- **No automatic retries.** Riverpod retries failed providers by default, which would also spend the 10 searches; the user retries instead.
- **One result set per keyword.** `searchResultsProvider` is an `autoDispose` family keyed by the keyword, so a new search starts empty and never shows the previous keyword's results. A keyword's results are dropped once the screen stops showing them.

### Pagination

`SearchResultsNotifier.loadNextPage()` appends the next page (100 results), and the list calls it as rows are built:

- **When:** once one of the last 50 rows (half a page) is built, several screens before the end, so the next page arrives before even a fast scroll gets there. Checking as rows are built, rather than on scroll, also loads more when the first page doesn't fill the screen.
- **At most one request at a time.** `loadNextPage` does nothing while a page or the search itself is loading, so the list can call it freely.
- **Failed pages.** The loaded results stay, and the end of the list shows the error with a Retry button. Scrolling doesn't request the page again; only Retry does.
- **Duplicates.** Results can shift between requests, so a page may repeat a repository; it is skipped.
- **Stale pages.** A page that arrives after the search reloaded is dropped.
- **The 1,000-result limit.** GitHub returns at most 1,000 results per search. When paging stops there while `total_count` is larger, the end of the list says only the first 1,000 results are shown and suggests a more specific search.
- **The end.** Once every result has been loaded, the end of the list says there are no more results.

### Avatars

`RepoAvatar` asks GitHub's avatar host for an image the size it is shown (the `s` parameter) and decodes it at that size, instead of the default 460 pixels. A placeholder shows while it loads, if it fails, or when a repository has no owner.

### Testing the screen

- `test/fixtures/` holds a real Search API response for `flutter`, the Repository API response for its first result, and their owners' avatars, saved by `dart run tool/fetch_fixtures.dart`. The parsers and the golden tests use them.
- `withAvatarFixtures` (`test/helpers/avatars.dart`) makes `Image.network` load those avatars instead of the network, through Flutter's `debugNetworkImageHttpClientProvider`, so goldens show real images.
- Golden tests cover the results, no results and rate limited states, and both ends of the list (every result shown, and the 1,000-result limit), at every device size. The detail screen has goldens for loaded, loading, rate limited and not found.

## Detail Screen

Tapping a search result opens `RepoDetailScreen` (`lib/ui/detail/`) within the tab, under the navigation bar.

- **Each tab has its own navigator** (`HomeShell`), so a tab keeps the screens opened in it while another tab is shown, and returns to the list where it was left.
- **Back:** the back button, the iOS edge swipe and Android's system back close the shown tab's screens; system back on a tab's first screen is left to the system. Hidden tabs are never popped.
- **Tapping the shown tab again** returns to its first screen, as in iOS apps.


- **Shown at once:** the owner avatar (96 pixels), `full_name` and the star button come from the search result, so they don't wait for the network.
- **Copying the name:** long-pressing `full_name` copies the whole name and confirms with a SnackBar. It copies directly instead of selecting text, which would select only the word under the finger.
- **Loaded:** `subscribers_count` comes from the Repository API through `repoDetailProvider` (`lib/state/repo_detail_provider.dart`), an `autoDispose` family keyed by full name, so reopening a repository loads its latest count. Like search, it never retries on its own: unauthenticated clients get 60 of these requests an hour.
- **States of the subscriber count:** a loading indicator; the count with thousands separators; or the error with a Retry button. A deleted repository (404) says it no longer exists and offers no retry, since retrying can't bring it back. The rest of the screen, including the star, stays usable.
- **Stars stay in sync:** the star button watches the same `isStarredProvider(id)` as the list rows, so starring here shows in the list on returning, without reloading anything.
- **Wide screens:** the content is at most 560 pixels wide, centered, so it stays readable on an iPad.

## Stars Screen

The Stars tab (`lib/ui/stars/`) lists the starred repositories, most recently starred first, from `favoritesProvider`.

- **Unstarring** a repository with its star button removes its row at once and saves the change (see [Favorites](#favorites)).
- **Empty state** when nothing is starred, pointing to Search.
- **In sync with the other screens:** it watches `favoritesProvider`, so stars added or removed in Search or on the detail screen show immediately, and unstarring here updates their star buttons. Widget tests drive the whole shell to check this end to end.
- **Tapping a row** opens the [detail screen](#detail-screen), as in Search.
- Stars are stored on the device, so the tab works offline; only the avatars need the network.

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
- Every change rewrites the whole array. shared_preferences can only replace a key's whole value, and one write always stores one complete list. Saves run one at a time, in order, so an older list can never finish last and overwrite a newer one.
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
