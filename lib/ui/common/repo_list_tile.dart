import 'package:flutter/material.dart';

import '../../data/github/github_repo.dart';
import 'repo_avatar.dart';

/// A repository's owner avatar and full name, as a list row.
class RepoListTile extends StatelessWidget {
  const RepoListTile({
    super.key,
    required this.repo,
    this.trailing,
    this.onTap,
  });

  final GitHubRepo repo;

  /// Shown at the end of the row, e.g. a star button.
  final Widget? trailing;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: RepoAvatar(url: repo.owner?.avatarUrl),
      title: Text(repo.fullName, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
