import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../data/github/github_api_exception.dart';
import '../../data/github/github_repo.dart';
import '../../state/repo_detail_provider.dart';
import '../common/error_message.dart';
import '../common/repo_avatar.dart';
import '../common/star_button.dart';

/// A repository's owner avatar, full name and subscriber count, with a star
/// button.
///
/// The avatar, name and star come from [repo], which the list already has,
/// so they show at once; only the subscriber count waits for the
/// Repository API.
class RepoDetailScreen extends StatelessWidget {
  const RepoDetailScreen({super.key, required this.repo});

  final GitHubRepo repo;

  /// The widest the content gets, so it stays readable on tablets.
  static const maxContentWidth = 560.0;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(actions: [StarButton(repo: repo)]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: maxContentWidth),
              child: Column(
                children: [
                  RepoAvatar(url: repo.owner?.avatarUrl, size: 96),
                  const SizedBox(height: 16),
                  Text(
                    repo.fullName,
                    style: textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  _Subscribers(fullName: repo.fullName),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The subscriber count, or why it couldn't load.
class _Subscribers extends ConsumerWidget {
  const _Subscribers({required this.fullName});

  final String fullName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = repoDetailProvider(fullName);
    final theme = Theme.of(context);
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: switch (ref.watch(provider)) {
          // Checked first: retrying keeps the previous error until it loads.
          AsyncValue(isLoading: true) => const Center(
            child: CircularProgressIndicator(),
          ),
          AsyncValue(:final error?) => Column(
            children: [
              Text(
                describeError(context, error).message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              // Retrying can't bring back a deleted repository.
              if (error is! NotFoundException) ...[
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: () => ref.invalidate(provider),
                  child: const Text('Retry'),
                ),
              ],
            ],
          ),
          AsyncValue(:final value?) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.visibility_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                _formatCount(value.subscribersCount),
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(width: 8),
              Text('Subscribers', style: theme.textTheme.bodyLarge),
            ],
          ),
          AsyncValue() => const SizedBox.shrink(),
        },
      ),
    );
  }
}

/// [count] with thousands separators, e.g. 1,234,567.
String _formatCount(int count) {
  final digits = '$count';
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
