import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:github_repo_viewer/ui/search/search_screen.dart';
import 'package:github_repo_viewer/ui/shell/app_tab.dart';
import 'package:github_repo_viewer/ui/shell/home_shell.dart';

import '../../helpers/golden_devices.dart';

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
