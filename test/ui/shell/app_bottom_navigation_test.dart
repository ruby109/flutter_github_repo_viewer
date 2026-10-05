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

    // A Material 3 navigation bar marks the current tab with an indicator
    // behind its icon, so it is obvious even for the Search tab, whose icon
    // is the same selected or not.
    testWidgets('highlights the current tab with an indicator', (tester) async {
      await pumpNavigation(tester, currentTab: AppTab.favorites);

      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, AppTab.favorites.index);
      expect(find.byType(NavigationIndicator), findsNWidgets(2));
      expect(find.byIcon(AppTab.favorites.selectedIcon), findsOneWidget);
      expect(find.byIcon(AppTab.favorites.icon), findsNothing);
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
