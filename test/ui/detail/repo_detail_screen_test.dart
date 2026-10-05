import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:github_repo_viewer/data/github/github_providers.dart';
import 'package:github_repo_viewer/data/github/github_repo.dart';
import 'package:github_repo_viewer/data/preferences/shared_preferences_provider.dart';
import 'package:github_repo_viewer/state/favorites_notifier.dart';
import 'package:github_repo_viewer/ui/common/repo_avatar.dart';
import 'package:github_repo_viewer/ui/common/star_button.dart';
import 'package:github_repo_viewer/ui/detail/repo_detail_screen.dart';

import '../../helpers/avatars.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/github_json.dart';
import '../../helpers/golden_devices.dart';
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

    group('long-pressing the name', () {
      testWidgets('copies the full name', (tester) async {
        String? copied;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copied =
                  (call.arguments as Map<Object?, Object?>)['text'] as String?;
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        await pumpScreen(tester, () async => found());
        await tester.pump();

        await tester.longPress(find.text('flutter/flutter'));
        await tester.pump();

        expect(copied, 'flutter/flutter');
        expect(find.text('Copied flutter/flutter'), findsOneWidget);
      });

      testWidgets('tells screen readers it can be copied', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpScreen(tester, () async => found());
        await tester.pump();

        expect(
          tester.getSemantics(find.text('flutter/flutter')),
          matchesSemantics(
            label: 'flutter/flutter',
            hasLongPressAction: true,
            onLongPressHint: 'Copy name',
          ),
        );
        semantics.dispose();
      });
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

    testWidgets('keeps the card the same width once loaded', (tester) async {
      final response = Completer<http.Response>();
      await pumpScreen(tester, () => response.future);
      final loadingWidth = tester.getSize(find.byType(Card)).width;

      response.complete(found());
      await tester.pump();

      expect(tester.getSize(find.byType(Card)).width, loadingWidth);
    });

    testWidgets('uses the singular for one subscriber', (tester) async {
      await pumpScreen(tester, () async => found(subscribers: 1));
      await tester.pump();

      expect(find.text('Subscriber'), findsOneWidget);
      expect(find.text('Subscribers'), findsNothing);
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

    // e.g. on an iPad, where a full-width card reads poorly.
    testWidgets('keeps its content readable on wide screens', (tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpScreen(tester, () async => found());
      await tester.pump();

      expect(
        tester.getSize(find.byType(Card)).width,
        lessThanOrEqualTo(RepoDetailScreen.maxContentWidth),
      );
    });

    // Accessibility text sizes on a narrow phone.
    testWidgets('fits the subscriber count with large text', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpScreen(tester, () async => found(subscribers: 1234567));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('1,234,567'), findsOneWidget);
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

    group('golden', () {
      /// Shows `flutter/flutter` from the fixtures, starred, with the
      /// Repository API answering [respond].
      Future<void> pumpFixture(
        WidgetTester tester,
        Future<http.Response> Function() respond,
      ) async {
        final detail = repoDetailFixture();
        final preferences = await inMemoryPreferences({
          FavoritesNotifier.storageKey: jsonEncode([detail]),
        });
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(preferences),
              httpClientProvider.overrideWithValue(
                MockClient((_) => respond()),
              ),
            ],
            // Pushed over another route, as in the app, so it has a back
            // button.
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: goldenTheme,
              darkTheme: goldenDarkTheme,
              initialRoute: '/detail',
              routes: {
                '/': (_) => const SizedBox.shrink(),
                '/detail': (_) =>
                    RepoDetailScreen(repo: GitHubRepo.fromJson(detail)),
              },
            ),
          ),
        );
      }

      Future<void> expectGolden(String state, GoldenDevice device) {
        return expectLater(
          find.byType(RepoDetailScreen),
          matchesGoldenFile(
            'goldens/repo_detail_screen_${state}_${device.name}.png',
          ),
        );
      }

      for (final device in goldenDevices) {
        for (final brightness in Brightness.values) {
          testGoldens('loaded', device, brightness: brightness, (tester) async {
            await withAvatarFixtures((_) async {
              await pumpFixture(
                tester,
                () async => http.Response.bytes(
                  utf8.encode(jsonEncode(repoDetailFixture())),
                  200,
                  headers: {'content-type': 'application/json; charset=utf-8'},
                ),
              );
              await tester.pump();
              await loadImages(tester);

              await expectGolden(
                'loaded${goldenModeSuffix(brightness)}',
                device,
              );
            });
          });
        }

        testGoldens('loading', device, (tester) async {
          final response = Completer<http.Response>();
          await withAvatarFixtures((_) async {
            await pumpFixture(tester, () => response.future);
            await loadImages(tester);
            // Past the progress indicator's first frame, which is a dot.
            await tester.pump(const Duration(milliseconds: 400));

            await expectGolden('loading', device);
          });
          // Finish the request so no timer is left pending.
          response.complete(http.Response('{}', 404));
          await tester.pump();
        });

        testGoldens('rate limited', device, (tester) async {
          await withAvatarFixtures((_) async {
            await pumpFixture(tester, () async => rateLimited());
            await tester.pump();
            await loadImages(tester);

            await expectGolden('rate_limited', device);
          });
        });

        testGoldens('not found', device, (tester) async {
          await withAvatarFixtures((_) async {
            await pumpFixture(tester, () async => http.Response('{}', 404));
            await tester.pump();
            await loadImages(tester);

            await expectGolden('not_found', device);
          });
        });
      }
    });
  });
}
