import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../data/preferences/shared_preferences_provider.dart';
import '../common/status_message.dart';

/// Shows [child] once the data the app needs at startup has loaded.
///
/// The app is shown only after the preferences have loaded, so favorites are
/// read synchronously and a star never flickers from empty to filled.
/// Until then it shows a plain background, or an error with a Retry button
/// if loading failed.
class AppStartupWidget extends ConsumerWidget {
  const AppStartupWidget({super.key, required this.child});

  /// The app, shown once startup has finished.
  final Widget child;

  /// The native launch screen's background in light and dark mode (the
  /// launch theme's background on Android, `systemBackground` in
  /// `LaunchScreen.storyboard` on iOS), so loading looks like the launch
  /// screen staying a moment longer.
  static const lightBackground = Color(0xFFFFFFFF);
  static const darkBackground = Color(0xFF000000);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(sharedPreferencesLoaderProvider)) {
      AsyncValue(hasValue: true) => child,
      // Retry shows the plain background again rather than the old error.
      AsyncValue(isLoading: true) => const _Loading(),
      AsyncValue(hasError: true) => _Error(
        onRetry: () => ref.invalidate(sharedPreferencesLoaderProvider),
      ),
      AsyncValue() => const _Loading(),
    };
  }
}

/// A plain background without a spinner: loading takes milliseconds, so a
/// spinner would only flash.
class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: switch (MediaQuery.platformBrightnessOf(context)) {
        Brightness.light => AppStartupWidget.lightBackground,
        Brightness.dark => AppStartupWidget.darkBackground,
      },
      child: const SizedBox.expand(),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StatusMessage(
          icon: Icons.error_outline,
          title: "Couldn't load your data",
          message:
              'Your starred repositories could not be read from this '
              'device. Try again.',
          action: FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ),
      ),
    );
  }
}
