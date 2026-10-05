import 'package:flutter/material.dart';

import 'app_tab.dart';

/// The tab bar: a [BottomNavigationBar] whose current tab's icon sits on an
/// indicator, like Material 3's navigation bar, so the selected tab is
/// obvious even when its icon doesn't change.
class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
  });

  final AppTab currentTab;
  final ValueChanged<AppTab> onTabSelected;

  /// The indicator behind the current tab's icon.
  static const indicatorKey = Key('AppBottomNavigation.indicator');

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return BottomNavigationBar(
      currentIndex: currentTab.index,
      onTap: (index) => onTabSelected(AppTab.values[index]),
      // As in Material 3: the indicator, not the colour, marks the tab.
      selectedItemColor: colorScheme.onSurface,
      unselectedItemColor: colorScheme.onSurfaceVariant,
      items: [
        for (final tab in AppTab.values)
          BottomNavigationBarItem(
            icon: Icon(tab.icon),
            activeIcon: DecoratedBox(
              key: indicatorKey,
              decoration: ShapeDecoration(
                color: colorScheme.secondaryContainer,
                shape: const StadiumBorder(),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                child: Icon(tab.selectedIcon),
              ),
            ),
            label: tab.label,
          ),
      ],
    );
  }
}
