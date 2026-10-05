import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:github_repo_viewer/ui/shell/app_bottom_navigation.dart';
import 'package:github_repo_viewer/ui/shell/app_tab.dart';

void main() {
  group('AppBottomNavigation', () {
    Future<void> pumpNavigation(
      WidgetTester tester, {
      required AppTab currentTab,
      ValueChanged<AppTab>? onTabSelected,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: AppBottomNavigation(
              currentTab: currentTab,
              onTabSelected: onTabSelected ?? (_) {},
            ),
          ),
        ),
      );
    }

    testWidgets('shows a labelled item for every tab', (tester) async {
      await pumpNavigation(tester, currentTab: AppTab.search);

      for (final tab in AppTab.values) {
        expect(find.text(tab.label), findsOneWidget);
      }
    });

    // The assignment asks for a BottomNavigationBar.
    testWidgets('is a bottom navigation bar', (tester) async {
      await pumpNavigation(tester, currentTab: AppTab.favorites);

      final bar = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(bar.currentIndex, AppTab.favorites.index);
    });

    // Colour alone barely marks the Search tab, whose icon is the same
    // selected or not, so the current tab's icon sits on an indicator.
    testWidgets('highlights the current tab with an indicator', (tester) async {
      await pumpNavigation(tester, currentTab: AppTab.search);

      final indicator = find.byKey(AppBottomNavigation.indicatorKey);
      expect(indicator, findsOneWidget);
      expect(
        find.descendant(
          of: indicator,
          matching: find.byIcon(AppTab.search.selectedIcon),
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows the selected icon only for the current tab', (
      tester,
    ) async {
      await pumpNavigation(tester, currentTab: AppTab.favorites);

      expect(find.byIcon(AppTab.favorites.selectedIcon), findsOneWidget);
      expect(find.byIcon(AppTab.favorites.icon), findsNothing);
      expect(find.byIcon(AppTab.search.icon), findsOneWidget);
    });

    testWidgets('reports the tapped tab', (tester) async {
      final selected = <AppTab>[];
      await pumpNavigation(
        tester,
        currentTab: AppTab.search,
        onTabSelected: selected.add,
      );

      await tester.tap(find.text(AppTab.favorites.label));

      expect(selected, [AppTab.favorites]);
    });
  });
}
