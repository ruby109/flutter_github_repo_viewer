import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../search/search_screen.dart';
import 'app_bottom_navigation.dart';
import 'app_tab.dart';

class HomeShell extends HookWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    // Tab selection is ephemeral UI state used only by this shell, so it stays
    // local. Lift it into a provider if something outside the shell needs to
    // switch tabs (e.g. deep links or notifications).
    final currentTab = useState(AppTab.search);

    return Scaffold(
      body: IndexedStack(
        index: currentTab.value.index,
        children: [
          for (final tab in AppTab.values)
            switch (tab) {
              // Opening a repository comes with the detail screen.
              AppTab.search => SearchScreen(onRepoTap: (_) {}),
              AppTab.favorites => Container(),
            },
        ],
      ),
      bottomNavigationBar: AppBottomNavigation(
        currentTab: currentTab.value,
        onTabSelected: (tab) => currentTab.value = tab,
      ),
    );
  }
}
