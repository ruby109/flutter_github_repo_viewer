import 'package:flutter_test/flutter_test.dart';

import 'package:github_repo_viewer/data/github/github_repo.dart';

void main() {
  group('GitHubRepo', () {
    Map<String, Object?> repoJson() => {
      'id': 10270250,
      'full_name': 'facebook/react',
      'owner': <String, Object?>{
        'login': 'facebook',
        'avatar_url': 'https://avatars.githubusercontent.com/u/69631?v=4',
      },
      'stargazers_count': 230000,
    };

    test('parses id, full_name and owner.avatar_url from JSON', () {
      final repo = GitHubRepo.fromJson(repoJson());

      expect(repo.id, 10270250);
      expect(repo.fullName, 'facebook/react');
      expect(
        repo.owner?.avatarUrl,
        'https://avatars.githubusercontent.com/u/69631?v=4',
      );
    });

    // The Search API documents `owner` as nullable (`nullable-simple-user`).
    test('parses a null owner as null', () {
      final repo = GitHubRepo.fromJson(repoJson()..['owner'] = null);

      expect(repo.owner, isNull);
    });

    // Favorites are stored in this shape and read back with fromJson.
    group('toJson', () {
      test('writes id, full_name and owner.avatar_url', () {
        const repo = GitHubRepo(
          id: 1,
          fullName: 'a/one',
          owner: Owner(avatarUrl: 'https://example.com/a.png'),
        );

        expect(repo.toJson(), {
          'id': 1,
          'full_name': 'a/one',
          'owner': {'avatar_url': 'https://example.com/a.png'},
        });
      });

      test('writes a null owner', () {
        const repo = GitHubRepo(id: 1, fullName: 'a/one', owner: null);

        expect(repo.toJson(), {'id': 1, 'full_name': 'a/one', 'owner': null});
      });

      test('round-trips through fromJson', () {
        final repo = GitHubRepo.fromJson(repoJson());

        final restored = GitHubRepo.fromJson(repo.toJson());

        expect(restored.id, repo.id);
        expect(restored.fullName, repo.fullName);
        expect(restored.owner?.avatarUrl, repo.owner?.avatarUrl);
      });
    });

    group('throws FormatException', () {
      final invalidCases = <String, void Function(Map<String, Object?>)>{
        'when id is missing': (json) => json.remove('id'),
        'when id is null': (json) => json['id'] = null,
        'when id is not an int': (json) => json['id'] = '10270250',
        'when full_name is missing': (json) => json.remove('full_name'),
        'when full_name is null': (json) => json['full_name'] = null,
        // owner is required but nullable, so only a missing key is invalid.
        'when owner is missing': (json) => json.remove('owner'),
        'when owner is not an object': (json) => json['owner'] = 'facebook',
        'when owner.avatar_url is null': (json) =>
            (json['owner']! as Map<String, Object?>)['avatar_url'] = null,
      };

      invalidCases.forEach((description, corrupt) {
        test(description, () {
          final json = repoJson();
          corrupt(json);

          expect(() => GitHubRepo.fromJson(json), throwsFormatException);
        });
      });
    });
  });
}
