import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../data/github/github_repo.dart';
import '../../state/search_query_notifier.dart';
import '../common/status_message.dart';
import 'search_results_view.dart';

/// Searches GitHub repositories by keyword.
///
/// Searches when the keyboard's search key is pressed, not while typing:
/// unauthenticated clients get only 10 searches a minute. An empty search
/// box shows the home state.
class SearchScreen extends HookConsumerWidget {
  const SearchScreen({super.key, required this.onRepoTap});

  final ValueChanged<GitHubRepo> onRepoTap;

  static const homeTitle = 'Search GitHub repositories';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useTextEditingController();
    final hasText = useValueListenable(controller).text.isNotEmpty;
    final query = ref.watch(searchQueryProvider);
    final queryNotifier = ref.read(searchQueryProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search repositories',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: hasText
                ? IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      controller.clear();
                      queryNotifier.clear();
                    },
                  )
                : null,
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(28)),
            ),
            isDense: true,
          ),
          onChanged: (text) {
            if (text.trim().isEmpty) queryNotifier.clear();
          },
          onSubmitted: queryNotifier.submit,
        ),
      ),
      body: query.isEmpty
          ? const StatusMessage(
              icon: Icons.search,
              title: homeTitle,
              message: 'Enter a keyword, then press search.',
            )
          : SearchResultsView(query: query, onRepoTap: onRepoTap),
    );
  }
}
