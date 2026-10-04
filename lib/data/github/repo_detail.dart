import 'github_repo.dart';

/// A repository as returned by the Repository API, which adds fields that
/// search results don't include.
class RepoDetail {
  const RepoDetail({required this.repo, required this.subscribersCount});

  /// Throws a [FormatException] if [json] isn't a valid repository object.
  factory RepoDetail.fromJson(Map<String, Object?> json) {
    return switch (json) {
      {'subscribers_count': final int subscribersCount} => RepoDetail(
        repo: GitHubRepo.fromJson(json),
        subscribersCount: subscribersCount,
      ),
      _ => throw FormatException('Invalid repository detail JSON', json),
    };
  }

  /// The fields shared with search results; also what gets starred.
  final GitHubRepo repo;

  /// Number of users watching the repository.
  final int subscribersCount;
}
