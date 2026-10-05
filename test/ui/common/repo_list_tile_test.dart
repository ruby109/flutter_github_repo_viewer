import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:github_repo_viewer/data/github/github_repo.dart';
import 'package:github_repo_viewer/ui/common/repo_avatar.dart';
import 'package:github_repo_viewer/ui/common/repo_list_tile.dart';

import '../../helpers/avatars.dart';

void main() {
  group('RepoListTile', () {
    const repo = GitHubRepo(
      id: 1,
      fullName: 'flutter/flutter',
      owner: Owner(avatarUrl: 'https://example.com/a.png'),
    );

    Future<void> pumpTile(
      WidgetTester tester,
      GitHubRepo repo, {
      Widget? trailing,
      VoidCallback? onTap,
    }) {
      return tester.pumpWidget(
        ProviderScope(
          overrides: [AvatarFixtures().override],
          child: MaterialApp(
            home: Scaffold(
              body: RepoListTile(repo: repo, trailing: trailing, onTap: onTap),
            ),
          ),
        ),
      );
    }

    String? avatarUrl(WidgetTester tester) =>
        tester.widget<RepoAvatar>(find.byType(RepoAvatar)).url;

    testWidgets('shows the full name and the owner avatar', (tester) async {
      await pumpTile(tester, repo);

      expect(find.text('flutter/flutter'), findsOneWidget);
      expect(avatarUrl(tester), 'https://example.com/a.png');
    });

    testWidgets('shows the avatar placeholder without an owner', (
      tester,
    ) async {
      await pumpTile(
        tester,
        const GitHubRepo(id: 1, fullName: 'flutter/flutter', owner: null),
      );

      expect(avatarUrl(tester), isNull);
    });

    testWidgets('shows the trailing widget', (tester) async {
      await pumpTile(tester, repo, trailing: const Icon(Icons.star));

      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var taps = 0;
      await pumpTile(tester, repo, onTap: () => taps++);

      await tester.tap(find.text('flutter/flutter'));

      expect(taps, 1);
    });

    testWidgets('fits a long name in two lines', (tester) async {
      await pumpTile(
        tester,
        GitHubRepo(id: 1, fullName: 'owner/${'a' * 300}', owner: null),
      );

      final text = tester.widget<Text>(find.textContaining('owner/'));
      expect(text.maxLines, 2);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    });
  });
}
