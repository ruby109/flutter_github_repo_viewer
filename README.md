# GitHub Repo Viewer

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

## Testing

```sh
flutter test
```

## Contributing

Commit conventions and other rules for contributors (human or AI agent) are in [AGENTS.md](AGENTS.md).
