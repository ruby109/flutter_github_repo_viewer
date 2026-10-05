import 'package:flutter_test/flutter_test.dart';

import 'package:github_repo_viewer/data/github/repo_detail.dart';

import '../../helpers/fixtures.dart';

void main() {
  group('RepoDetail', () {
    Map<String, Object?> detailJson() => {
      'id': 10270250,
      'full_name': 'facebook/react',
      'owner': <String, Object?>{
        'login': 'facebook',
        'avatar_url': 'https://avatars.githubusercontent.com/u/69631?v=4',
      },
      'subscribers_count': 6600,
    };

    test('parses the repository and subscribers_count from JSON', () {
      final detail = RepoDetail.fromJson(detailJson());

      expect(detail.repo.id, 10270250);
      expect(detail.repo.fullName, 'facebook/react');
      expect(
        detail.repo.owner?.avatarUrl,
        'https://avatars.githubusercontent.com/u/69631?v=4',
      );
      expect(detail.subscribersCount, 6600);
    });

    test('parses a real Repository API response', () {
      final detail = RepoDetail.fromJson(repoDetailFixture());

      expect(detail.repo.fullName, 'flutter/flutter');
      expect(
        detail.repo.owner?.avatarUrl,
        'https://avatars.githubusercontent.com/u/14101776?v=4',
      );
      expect(detail.subscribersCount, greaterThan(0));
    });

    group('throws FormatException', () {
      final invalidCases = <String, void Function(Map<String, Object?>)>{
        'when subscribers_count is missing': (json) =>
            json.remove('subscribers_count'),
        'when subscribers_count is null': (json) =>
            json['subscribers_count'] = null,
        'when subscribers_count is not an int': (json) =>
            json['subscribers_count'] = '6600',
        'when the repository fields are invalid': (json) => json.remove('id'),
      };

      invalidCases.forEach((description, corrupt) {
        test(description, () {
          final json = detailJson();
          corrupt(json);

          expect(() => RepoDetail.fromJson(json), throwsFormatException);
        });
      });
    });
  });
}
