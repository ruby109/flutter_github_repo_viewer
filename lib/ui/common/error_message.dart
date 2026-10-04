import 'package:flutter/material.dart';

import '../../data/github/github_api_exception.dart';

/// What to tell the user about an error.
typedef ErrorMessage = ({IconData icon, String title, String message});

/// Describes [error] for the user, e.g. when to retry after rate limiting.
ErrorMessage describeError(BuildContext context, Object error) {
  const somethingWentWrong = 'Something went wrong';
  return switch (error) {
    RateLimitException(:final retryAt) => (
      icon: Icons.hourglass_empty,
      title: 'Too many requests',
      message:
          'GitHub limits how often the app can ask without signing in. '
          '${retryAt == null ? 'Wait a minute and try again.' : 'Try again after ${_formatTime(context, retryAt)}.'}',
    ),
    NetworkException() => (
      icon: Icons.wifi_off,
      title: 'No connection',
      message: 'Check your internet connection and try again.',
    ),
    NotFoundException() => (
      icon: Icons.search_off,
      title: 'Not found',
      message: 'This repository no longer exists.',
    ),
    HttpStatusException(:final statusCode) => (
      icon: Icons.error_outline,
      title: somethingWentWrong,
      message: 'GitHub answered with an error ($statusCode). Try again.',
    ),
    MalformedResponseException() => (
      icon: Icons.error_outline,
      title: somethingWentWrong,
      message: "GitHub's response couldn't be read. Try again.",
    ),
    _ => (
      icon: Icons.error_outline,
      title: somethingWentWrong,
      message: 'Try again.',
    ),
  };
}

String _formatTime(BuildContext context, DateTime time) {
  return MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay.fromDateTime(time.toLocal()),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
}
