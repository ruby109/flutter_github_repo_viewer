import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../data/github/github_repo.dart';
import '../detail/repo_detail_screen.dart';
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

    // Each tab has its own navigator, so screens opened in a tab stay under
    // the navigation bar, and each tab keeps them while another is shown.
    final navigators = useMemoized(
      () => {for (final tab in AppTab.values) tab: GlobalKey<NavigatorState>()},
    );

    Widget firstScreen(AppTab tab) {
      void openRepo(GitHubRepo repo) => navigators[tab]!.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => RepoDetailScreen(repo: repo)),
      );
      return switch (tab) {
        AppTab.search => SearchScreen(onRepoTap: openRepo),
        AppTab.favorites => Container(),
      };
    }

    return Scaffold(
      body: IndexedStack(
        index: currentTab.value.index,
        children: [
          for (final tab in AppTab.values)
            // System back first closes the shown tab's screens; on its first
            // screen it is left to the system (e.g. leaving the app).
            NavigatorPopHandler<Object?>(
              enabled: tab == currentTab.value,
              onPopWithResult: (_) => navigators[tab]!.currentState!.maybePop(),
              child: Navigator(
                key: navigators[tab],
                onGenerateInitialRoutes: (_, _) => [
                  MaterialPageRoute<void>(builder: (_) => firstScreen(tab)),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: AppBottomNavigation(
        currentTab: currentTab.value,
        onTabSelected: (tab) {
          // Tapping the shown tab again returns to its first screen, as on
          // iOS.
          if (tab == currentTab.value) {
            navigators[tab]!.currentState!.popUntil((route) => route.isFirst);
          }
          currentTab.value = tab;
        },
      ),
    );
  }
}
