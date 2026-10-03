---
name: golden-test
description: Add or update golden (snapshot) tests for a screen or widget in this project, rendered at iPhone 17, iPhone SE, iPad and Android phone sizes. Use when building or changing UI that should be covered by golden files, or when golden tests fail on a pull request.
---

# Golden tests in this project

Golden tests use Flutter's built-in `matchesGoldenFile` only — no third-party
packages (the assignment asks us to avoid them). The shared setup lives in:

- `test/flutter_test_config.dart`: loads Roboto and Material Icons from the
  Flutter SDK so text and icons render (otherwise every glyph is a box).
- `test/helpers/golden_devices.dart`: `goldenDevices` (iPhone 17, iPhone SE,
  iPad, Android phone) and `testGoldens`, which sizes the view, adds safe-area
  insets, enables real shadows and tags the test `golden`.

## Writing a golden test

Put golden tests in the widget's existing test file (tests mirror `lib/`),
inside a `group('golden', ...)`:

```dart
group('golden', () {
  for (final device in goldenDevices) {
    testGoldens('search tab', device, (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: HomeShell(),
        ),
      );

      await expectLater(
        find.byType(HomeShell),
        matchesGoldenFile('goldens/home_shell_search_${device.name}.png'),
      );
    });
  }
});
```

Rules:

- Always pass `debugShowCheckedModeBanner: false`.
- Name files `goldens/<file_under_test>_<state>_<device>.png`, next to the test.
- Cover each meaningful state (e.g. each tab, empty / loading / loaded / error).
- Make the widget deterministic first: override providers with fake data, no
  real network, no current time or random values. For async images, settle with
  `tester.pumpAndSettle()` before matching.

## Generating and updating golden files

Never commit golden files generated on macOS: CI compares them on Linux, and
font rendering differs between the two. Instead:

1. Push the branch.
2. Run `scripts/update-goldens.sh` (or trigger the "Golden Tests" workflow with
   `update: true`). CI regenerates the PNGs on Linux and commits them as
   `test: update golden files`; the script waits and pulls the commit.
3. Look at the new PNGs before merging. They are the expected output.

Locally you can still render goldens to eyeball a layout:
`flutter test --tags golden --update-goldens`, then discard the PNGs
(`git checkout -- '*.png'` / delete new ones) instead of committing them.

## When golden tests fail on a PR

The "Golden Tests" workflow uploads a `golden-failures` artifact containing,
for each mismatch, the expected (`*_masterImage.png`), actual
(`*_testImage.png`) and diff images. If the change is intended, regenerate with
`scripts/update-goldens.sh`; otherwise fix the UI.

Regular `flutter test` runs (pre-push hook, CI workflow) exclude the `golden`
tag; only `.github/workflows/golden.yml` runs them.
