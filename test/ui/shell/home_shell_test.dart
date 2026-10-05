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

import '../../helpers/github_json.dart';
import '../../helpers/golden_devices.dart';
import '../../helpers/preferences.dart';

void main() {
  group('HomeShell', () {
    Future<void> pumpShell(WidgetTester tester) {
      return tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: HomeShell())),
      );
    }

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

    /// The shell over a GitHub API that finds `flutter/flutter` and
    /// reports 3,546 subscribers for it.
    Future<void> pumpWithApi(WidgetTester tester) async {
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

    group('opening a repository', () {
      testWidgets('opens it when a search result is tapped', (tester) async {
        await pumpWithApi(tester);

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
        await pumpWithApi(tester);
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
        await pumpWithApi(tester);
        await tester.tap(find.text('flutter/flutter'));
        await tester.pumpAndSettle();
      }

      Finder tabItem(AppTab tab) => find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text(tab.label),
      );

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
        await pumpWithApi(tester);

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

      await tester.tap(find.text(AppTab.favorites.label));
      await tester.pump();

      expect(navBar(tester).currentIndex, AppTab.favorites.index);
      expect(body(tester).index, AppTab.favorites.index);

      await tester.tap(find.text(AppTab.search.label));
      await tester.pump();

      expect(navBar(tester).currentIndex, AppTab.search.index);
      expect(body(tester).index, AppTab.search.index);
    });

    group('golden', () {
      for (final device in goldenDevices) {
        for (final tab in AppTab.values) {
          testGoldens('${tab.name} tab', device, (tester) async {
            await tester.pumpWidget(
              const ProviderScope(
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  home: HomeShell(),
                ),
              ),
            );
            await tester.tap(find.text(tab.label));
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
