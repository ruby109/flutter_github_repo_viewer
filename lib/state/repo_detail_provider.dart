import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../data/github/github_providers.dart';
import '../data/github/repo_detail.dart';

/// The details of the repository with this full name (`owner/name`).
///
/// Disposed once no screen shows the repository, so reopening it loads
/// the latest details.
///
/// Doesn't retry failed requests on its own: unauthenticated clients get
/// 60 requests an hour, and automatic retries would use them up. Invalidate
/// it to try again.
final repoDetailProvider = FutureProvider.autoDispose
    .family<RepoDetail, String>(
      (ref, fullName) =>
          ref.watch(gitHubApiClientProvider).fetchRepository(fullName),
      retry: (_, _) => null,
    );
