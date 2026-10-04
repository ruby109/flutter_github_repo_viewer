/// The owner of a GitHub repository.
class Owner {
  const Owner({required this.avatarUrl});

  /// Throws a [FormatException] if [json] isn't a valid owner object.
  factory Owner.fromJson(Object? json) {
    return switch (json) {
      {'avatar_url': final String avatarUrl} => Owner(avatarUrl: avatarUrl),
      _ => throw FormatException('Invalid owner JSON', json),
    };
  }

  final String avatarUrl;
}

/// A repository as listed in GitHub search results.
class GitHubRepo {
  const GitHubRepo({
    required this.id,
    required this.fullName,
    required this.owner,
  });

  /// Throws a [FormatException] if [json] isn't a valid repository object.
  factory GitHubRepo.fromJson(Map<String, Object?> json) {
    return switch (json) {
      {'id': final int id, 'full_name': final String fullName} => GitHubRepo(
        id: id,
        fullName: fullName,
        owner: switch (json['owner']) {
          null => null,
          final owner => Owner.fromJson(owner),
        },
      ),
      _ => throw FormatException('Invalid repository JSON', json),
    };
  }

  final int id;

  /// `owner/name`, e.g. `flutter/flutter`.
  final String fullName;

  /// Null when GitHub returns no owner, which the Search API allows.
  final Owner? owner;
}
