/// The owner of a GitHub repository.
class Owner {
  const Owner({required this.avatarUrl});

  factory Owner.fromJson(Map<String, Object?> json) {
    return Owner(avatarUrl: json['avatar_url'] as String);
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

  factory GitHubRepo.fromJson(Map<String, Object?> json) {
    return GitHubRepo(
      id: json['id'] as int,
      fullName: json['full_name'] as String,
      owner: Owner.fromJson(json['owner'] as Map<String, Object?>),
    );
  }

  final int id;

  /// `owner/name`, e.g. `flutter/flutter`.
  final String fullName;

  final Owner owner;
}
