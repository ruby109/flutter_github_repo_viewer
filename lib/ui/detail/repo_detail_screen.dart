import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
                  _CopyableName(
                    fullName: repo.fullName,
                    style: textTheme.headlineSmall,
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

/// The repository's full name; long-pressing it shows the platform's copy
/// menu (the edit menu on iOS, the text toolbar on Android), whose Copy
/// copies the whole name.
///
/// A menu rather than selectable text, which would select only the word
/// under the finger (e.g. one half of `flutter/flutter`).
class _CopyableName extends StatefulWidget {
  const _CopyableName({required this.fullName, required this.style});

  final String fullName;
  final TextStyle? style;

  @override
  State<_CopyableName> createState() => _CopyableNameState();
}

class _CopyableNameState extends State<_CopyableName> {
  final _menu = ContextMenuController();

  /// Groups the name and its menu, so tapping either doesn't count as
  /// tapping elsewhere.
  final _tapRegion = Object();

  @override
  void dispose() {
    _menu.remove();
    super.dispose();
  }

  void _showMenu(Offset position) {
    HapticFeedback.selectionClick();
    _menu.show(
      context: context,
      contextMenuBuilder: (context) => TapRegion(
        groupId: _tapRegion,
        child: AdaptiveTextSelectionToolbar.buttonItems(
          anchors: TextSelectionToolbarAnchors(primaryAnchor: position),
          buttonItems: [
            ContextMenuButtonItem(
              type: ContextMenuButtonType.copy,
              onPressed: () {
                _menu.remove();
                Clipboard.setData(ClipboardData(text: widget.fullName));
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      groupId: _tapRegion,
      onTapOutside: (_) => _menu.remove(),
      child: Semantics(
        onLongPressHint: 'Show copy menu',
        child: GestureDetector(
          onLongPressStart: (details) => _showMenu(details.globalPosition),
          child: Text(
            widget.fullName,
            style: widget.style,
            textAlign: TextAlign.center,
          ),
        ),
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
    // Full width in every state, so the card doesn't resize as it loads.
    return Card.outlined(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        child: switch (ref.watch(provider)) {
          // Checked first: retrying keeps the previous error until it loads.
          AsyncValue(isLoading: true) => const Center(
            child: CircularProgressIndicator.adaptive(),
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
          // Wraps rather than overflows with large text on narrow screens.
          AsyncValue(:final value?) => Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Icon(
                Icons.visibility_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              Text(
                _formatCount(value.subscribersCount),
                style: theme.textTheme.titleLarge,
              ),
              Text(
                value.subscribersCount == 1 ? 'Subscriber' : 'Subscribers',
                style: theme.textTheme.bodyLarge,
              ),
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
