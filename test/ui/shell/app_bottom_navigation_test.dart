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

    testWidgets('highlights the current tab with its selected icon', (
      tester,
    ) async {
      await pumpNavigation(tester, currentTab: AppTab.favorites);

      final navBar = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(navBar.currentIndex, AppTab.favorites.index);
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
