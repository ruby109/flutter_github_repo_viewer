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

/// The requested resource doesn't exist (404), e.g. a deleted repository.
final class NotFoundException extends GitHubApiException {
  const NotFoundException();

  @override
  String toString() => 'NotFoundException()';
}

/// GitHub answered with an unexpected HTTP status.
final class HttpStatusException extends GitHubApiException {
  const HttpStatusException(this.statusCode);

  final int statusCode;

  @override
  String toString() => 'HttpStatusException($statusCode)';
}

/// The request didn't complete: no connection, a dropped connection or a
/// timeout.
final class NetworkException extends GitHubApiException {
  const NetworkException(this.cause);

  /// The underlying error, e.g. an `http.ClientException` or a
  /// `TimeoutException`.
  final Object cause;

  @override
  String toString() => 'NetworkException($cause)';
}

/// GitHub answered with a body the app can't read, e.g. not JSON or missing
/// required fields.
final class MalformedResponseException extends GitHubApiException {
  const MalformedResponseException(this.cause);

  /// The [FormatException] describing what was wrong.
  final FormatException cause;

  @override
  String toString() => 'MalformedResponseException($cause)';
}
