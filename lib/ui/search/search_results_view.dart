import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../data/github/github_repo.dart';
import '../../state/search_results_notifier.dart';
import '../common/error_message.dart';
import '../common/status_message.dart';
import 'search_results_list.dart';

/// The results for [query]: loading, an error, no results, or the list.
class SearchResultsView extends ConsumerWidget {
  const SearchResultsView({
    super.key,
    required this.query,
    required this.onRepoTap,
  });

  final String query;
  final ValueChanged<GitHubRepo> onRepoTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = searchResultsProvider(query);
    return switch (ref.watch(provider)) {
      // Checked first: retrying keeps the previous error until it loads.
      AsyncValue(isLoading: true) => const Center(
        child: CircularProgressIndicator(),
      ),
      AsyncValue(:final error?) => _ErrorMessage(
        error: error,
        onRetry: () => ref.invalidate(provider),
      ),
      AsyncValue(:final value?) when value.items.isEmpty => StatusMessage(
        icon: Icons.search_off,
        title: 'No results',
        message: 'No repositories match "$query". Try another keyword.',
      ),
      AsyncValue(:final value?) => SearchResultsList(
        results: value,
        onRepoTap: onRepoTap,
      ),
      AsyncValue() => const SizedBox.shrink(),
    };
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final (:icon, :title, :message) = describeError(context, error);
    return StatusMessage(
      icon: icon,
      title: title,
      message: message,
      action: FilledButton.tonal(
        onPressed: onRetry,
        child: const Text('Retry'),
      ),
    );
  }
}
