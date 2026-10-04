import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../data/github/github_repo.dart';
import '../detail/repo_detail_screen.dart';
import '../search/search_screen.dart';
import '../stars/stars_screen.dart';
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

    // Pushed over the shell: the detail screen has its own back button, and
    // each tab keeps its scroll position underneath.
    void openRepo(GitHubRepo repo) => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => RepoDetailScreen(repo: repo)),
    );

    return Scaffold(
      body: IndexedStack(
        index: currentTab.value.index,
        children: [
          for (final tab in AppTab.values)
            switch (tab) {
              AppTab.search => SearchScreen(onRepoTap: openRepo),
              AppTab.favorites => StarsScreen(onRepoTap: openRepo),
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
