/// A failed GitHub API call.
///
/// Sealed so callers can `switch` over every kind of failure.
sealed class GitHubApiException implements Exception {
  const GitHubApiException();
}

/// GitHub refused the request because the rate limit was exceeded.
///
/// Unauthenticated clients get 10 searches and 60 other requests a minute
/// per IP address.
final class RateLimitException extends GitHubApiException {
  const RateLimitException({this.retryAt});

  /// When requests may be retried, if GitHub said so.
  final DateTime? retryAt;

  @override
  String toString() => 'RateLimitException(retryAt: $retryAt)';
}
