import 'package:flutter_test/flutter_test.dart';

import 'package:github_repo_viewer/data/github/github_repo.dart';

void main() {
  group('GitHubRepo', () {
    test('parses id, full_name and owner.avatar_url from JSON', () {
      final repo = GitHubRepo.fromJson({
        'id': 10270250,
        'full_name': 'facebook/react',
        'owner': {
          'login': 'facebook',
          'avatar_url': 'https://avatars.githubusercontent.com/u/69631?v=4',
        },
        'stargazers_count': 230000,
      });

      expect(repo.id, 10270250);
      expect(repo.fullName, 'facebook/react');
      expect(
        repo.owner.avatarUrl,
        'https://avatars.githubusercontent.com/u/69631?v=4',
      );
    });
  });
}
