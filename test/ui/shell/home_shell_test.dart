import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:github_repo_viewer/data/github/github_providers.dart';
import 'package:github_repo_viewer/data/preferences/shared_preferences_provider.dart';
import 'package:github_repo_viewer/ui/common/repo_list_tile.dart';
import 'package:github_repo_viewer/ui/detail/repo_detail_screen.dart';

import 'package:github_repo_viewer/ui/search/search_screen.dart';
import 'package:github_repo_viewer/ui/shell/app_tab.dart';
import 'package:github_repo_viewer/ui/shell/home_shell.dart';
import 'package:github_repo_viewer/ui/stars/stars_screen.dart';

import '../../helpers/github_json.dart';
import '../../helpers/golden_devices.dart';
import '../../helpers/preferences.dart';

void main() {
  group('HomeShell', () {
    Future<void> pumpShell(WidgetTester tester) async {
      return tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(
              await inMemoryPreferences(),
            ),
          ],
          child: const MaterialApp(home: HomeShell()),
        ),
      );
    }

    /// The shell over a GitHub API that finds `flutter/flutter` and
    /// reports 3,546 subscribers for it, after searching `flutter`.
    Future<void> pumpSearched(WidgetTester tester) async {
      final preferences = await inMemoryPreferences();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            httpClientProvider.overrideWithValue(
              MockClient((request) async {
                final repo = repoJson(id: 7, fullName: 'flutter/flutter');
                return http.Response(
                  jsonEncode(
                    request.url.path == '/search/repositories'
                        ? searchJson(totalCount: 1, items: [repo])
                        : (repo..['subscribers_count'] = 3546),
                  ),
                  200,
                );
              }),
            ),
          ],
          child: const MaterialApp(home: HomeShell()),
        ),
      );
      await tester.enterText(find.byType(TextField), 'flutter');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
    }

    /// The bottom navigation item for [tab]; screens may show its label too.
    Finder tabItem(AppTab tab) => find.descendant(
      of: find.byType(BottomNavigationBar),
      matching: find.text(tab.label),
    );

    Future<void> openTab(WidgetTester tester, AppTab tab) async {
      await tester.tap(tabItem(tab));
      await tester.pumpAndSettle();
    }

    /// The star button of the `flutter/flutter` row in [screen].
    Finder starIn(Type screen, String tooltip) => find.descendant(
      of: find.descendant(
        of: find.byType(screen),
        matching: find.widgetWithText(RepoListTile, 'flutter/flutter'),
      ),
      matching: find.byTooltip(tooltip),
    );

    BottomNavigationBar navBar(WidgetTester tester) =>
        tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));

    IndexedStack body(WidgetTester tester) =>
        tester.widget<IndexedStack>(find.byType(IndexedStack));

    testWidgets('starts on the search tab', (tester) async {
      await pumpShell(tester);

      expect(navBar(tester).currentIndex, AppTab.search.index);
      expect(body(tester).index, AppTab.search.index);
    });

    testWidgets('shows the search screen on the search tab', (tester) async {
      await pumpShell(tester);

      expect(find.byType(SearchScreen), findsOneWidget);
    });

    testWidgets('shows the stars screen on the stars tab', (tester) async {
      await pumpShell(tester);

      await openTab(tester, AppTab.favorites);

      expect(find.byType(StarsScreen), findsOneWidget);
    });

    group('stars stay in sync across tabs', () {
      testWidgets('starring a search result adds it to the stars tab, and '
          'unstarring it there updates the search list', (tester) async {
        await pumpSearched(tester);

        await tester.tap(starIn(SearchScreen, 'Star'));
        await tester.pump();
        await openTab(tester, AppTab.favorites);

        expect(starIn(StarsScreen, 'Unstar'), findsOneWidget);

        await tester.tap(starIn(StarsScreen, 'Unstar'));
        await tester.pump();

        expect(find.text(StarsScreen.emptyTitle), findsOneWidget);

        await openTab(tester, AppTab.search);

        expect(starIn(SearchScreen, 'Star'), findsOneWidget);
      });

      testWidgets('starring on the detail screen adds it to the stars tab', (
        tester,
      ) async {
        await pumpSearched(tester);
        await tester.tap(find.text('flutter/flutter'));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Star'));
        await tester.pump();
        await tester.pageBack();
        await tester.pumpAndSettle();
        await openTab(tester, AppTab.favorites);

        expect(starIn(StarsScreen, 'Unstar'), findsOneWidget);
      });

      testWidgets('tapping a starred repository opens it', (tester) async {
        await pumpSearched(tester);
        await tester.tap(starIn(SearchScreen, 'Star'));
        await tester.pump();
        await openTab(tester, AppTab.favorites);

        await tester.tap(
          find.descendant(
            of: find.byType(StarsScreen),
            matching: find.text('flutter/flutter'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(RepoDetailScreen), findsOneWidget);
        expect(find.text('3,546'), findsOneWidget);
        // Opened within the Stars tab, under the navigation bar.
        expect(find.byType(BottomNavigationBar).hitTestable(), findsOneWidget);

        await openTab(tester, AppTab.search);

        expect(find.byType(RepoDetailScreen).hitTestable(), findsNothing);
      });
    });

    group('opening a repository', () {
      testWidgets('opens it when a search result is tapped', (tester) async {
        await pumpSearched(tester);

        await tester.tap(find.text('flutter/flutter'));
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<RepoDetailScreen>(find.byType(RepoDetailScreen))
              .repo
              .id,
          7,
        );
        expect(find.text('3,546'), findsOneWidget);
      });

      testWidgets('shows the star changed there on returning to the list', (
        tester,
      ) async {
        await pumpSearched(tester);
        await tester.tap(find.text('flutter/flutter'));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Star'));
        await tester.pump();
        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(find.byType(RepoDetailScreen), findsNothing);
        expect(
          find.descendant(
            of: find.widgetWithText(RepoListTile, 'flutter/flutter'),
            matching: find.byTooltip('Unstar'),
          ),
          findsOneWidget,
        );
      });
    });

    group('each tab keeps its own screens', () {
      Future<void> openResult(WidgetTester tester) async {
        await pumpSearched(tester);
        await tester.tap(find.text('flutter/flutter'));
        await tester.pumpAndSettle();
      }

      final detail = find.byType(RepoDetailScreen);

      testWidgets('keeps the navigation bar under the detail screen', (
        tester,
      ) async {
        await openResult(tester);

        expect(detail, findsOneWidget);
        expect(find.byType(BottomNavigationBar).hitTestable(), findsOneWidget);
      });

      testWidgets('system back returns from the detail screen to the list', (
        tester,
      ) async {
        await openResult(tester);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(detail, findsNothing);
        expect(find.text('flutter/flutter'), findsOneWidget);
      });

      // On the first screen of a tab, the system decides (e.g. leaves the
      // app on Android).
      testWidgets('leaves system back on a first screen to the system', (
        tester,
      ) async {
        await pumpSearched(tester);

        final handled = await tester.binding.handlePopRoute();

        expect(handled, isFalse);
      });

      testWidgets('system back leaves the screens of hidden tabs alone', (
        tester,
      ) async {
        await openResult(tester);
        await tester.tap(tabItem(AppTab.favorites));
        await tester.pumpAndSettle();

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await tester.tap(tabItem(AppTab.search));
        await tester.pumpAndSettle();

        expect(detail.hitTestable(), findsOneWidget);
      });

      testWidgets('tapping the current tab returns to its first screen', (
        tester,
      ) async {
        await openResult(tester);

        await tester.tap(tabItem(AppTab.search));
        await tester.pumpAndSettle();

        expect(detail, findsNothing);
        expect(find.text('flutter/flutter'), findsOneWidget);
      });

      // e.g. a loading indicator on a hidden detail screen would keep
      // scheduling frames.
      testWidgets('stops animations on hidden tabs', (tester) async {
        await openResult(tester);
        bool animates() => TickerMode.valuesOf(
          tester.element(find.byType(RepoDetailScreen, skipOffstage: false)),
        ).enabled;

        expect(animates(), isTrue);

        await tester.tap(tabItem(AppTab.favorites));
        await tester.pumpAndSettle();

        expect(animates(), isFalse);

        await tester.tap(tabItem(AppTab.search));
        await tester.pumpAndSettle();

        expect(animates(), isTrue);
      });

      testWidgets('keeps the detail screen open while on another tab', (
        tester,
      ) async {
        await openResult(tester);

        await tester.tap(tabItem(AppTab.favorites));
        await tester.pumpAndSettle();

        expect(detail.hitTestable(), findsNothing);

        await tester.tap(tabItem(AppTab.search));
        await tester.pumpAndSettle();

        expect(detail.hitTestable(), findsOneWidget);
      });
    });

    testWidgets('switches content and navigation when a tab is tapped', (
      tester,
    ) async {
      await pumpShell(tester);

      await tester.tap(tabItem(AppTab.favorites));
      await tester.pump();

      expect(navBar(tester).currentIndex, AppTab.favorites.index);
      expect(body(tester).index, AppTab.favorites.index);

      await tester.tap(tabItem(AppTab.search));
      await tester.pump();

      expect(navBar(tester).currentIndex, AppTab.search.index);
      expect(body(tester).index, AppTab.search.index);
    });

    group('golden', () {
      for (final device in goldenDevices) {
        for (final tab in AppTab.values) {
          testGoldens('${tab.name} tab', device, (tester) async {
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  sharedPreferencesProvider.overrideWithValue(
                    await inMemoryPreferences(),
                  ),
                ],
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: goldenTheme,
                  darkTheme: goldenDarkTheme,
                  home: const HomeShell(),
                ),
              ),
            );
            await tester.tap(tabItem(tab));
            await tester.pumpAndSettle();

            await expectLater(
              find.byType(HomeShell),
              matchesGoldenFile(
                'goldens/home_shell_${tab.name}_${device.name}.png',
              ),
            );
          });
        }
      }
    });
  });
}
