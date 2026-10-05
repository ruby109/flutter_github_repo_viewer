import 'package:flutter/material.dart';

import 'app_tab.dart';

/// The tab bar: a Material 3 navigation bar, which marks the current tab
/// with an indicator behind its icon, so the selected tab is obvious even
/// when its icon doesn't change.
class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
  });

  final AppTab currentTab;
  final ValueChanged<AppTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentTab.index,
      onDestinationSelected: (index) => onTabSelected(AppTab.values[index]),
      destinations: [
        for (final tab in AppTab.values)
          NavigationDestination(
            icon: Icon(tab.icon),
            selectedIcon: Icon(tab.selectedIcon),
            label: tab.label,
          ),
      ],
    );
  }
}
