import 'package:flutter/material.dart';

/// A centered icon, title, message and action, for screens with nothing
/// else to show: a starting point, no results or an error.
class StatusMessage extends StatelessWidget {
  const StatusMessage({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;

  /// e.g. a retry button.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = this.message;
    final action = this.action;
    // Scrolls when space is short, e.g. on a small phone with the keyboard
    // open.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 24), action],
          ],
        ),
      ),
    );
  }
}
