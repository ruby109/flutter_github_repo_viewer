import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:github_repo_viewer/ui/common/repo_avatar.dart';

import '../../helpers/avatars.dart';

void main() {
  group('RepoAvatar', () {
    const flutterAvatar =
        'https://avatars.githubusercontent.com/u/14101776?v=4';

    late AvatarFixtures avatars;

    setUp(() => avatars = AvatarFixtures());

    Future<void> pumpAvatar(
      WidgetTester tester,
      String? url, {
      double size = 40,
    }) {
      return tester.pumpWidget(
        ProviderScope(
          overrides: [avatars.override],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(devicePixelRatio: 2),
              child: Center(
                child: RepoAvatar(url: url, size: size),
              ),
            ),
          ),
        ),
      );
    }

    final placeholder = find.byIcon(RepoAvatar.placeholderIcon);

    // The Search API allows repositories without an owner.
    testWidgets('shows a placeholder without an avatar URL', (tester) async {
      await pumpAvatar(tester, null);

      expect(placeholder, findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    // owner.avatar_url is any string the API returned.
    testWidgets('shows a placeholder for an avatar URL it cannot parse', (
      tester,
    ) async {
      await pumpAvatar(tester, 'https://[');

      expect(tester.takeException(), isNull);
      expect(placeholder, findsOneWidget);
    });

    testWidgets('shows the avatar once it loads', (tester) async {
      await pumpAvatar(tester, flutterAvatar);

      expect(placeholder, findsOneWidget);

      await loadImages(tester);

      expect(placeholder, findsNothing);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('shows a placeholder when the avatar fails to load', (
      tester,
    ) async {
      await pumpAvatar(tester, 'https://avatars.githubusercontent.com/u/404');

      await loadImages(tester);

      expect(placeholder, findsOneWidget);
    });

    testWidgets('tries a failed avatar again when shown again', (tester) async {
      avatars.offline = true;
      await pumpAvatar(tester, flutterAvatar);
      await loadImages(tester);
      expect(placeholder, findsOneWidget);

      avatars.offline = false;
      await tester.pumpWidget(const SizedBox());
      await pumpAvatar(tester, flutterAvatar);
      await loadImages(tester);

      expect(placeholder, findsNothing);
    });

    // A 200 response that isn't an image must not stay cached.
    testWidgets('downloads an avatar again after it failed to decode', (
      tester,
    ) async {
      avatars.corrupt = true;
      await pumpAvatar(tester, flutterAvatar);
      await loadImages(tester);
      expect(placeholder, findsOneWidget);

      avatars.corrupt = false;
      await tester.pumpWidget(const SizedBox());
      await pumpAvatar(tester, flutterAvatar);
      await loadImages(tester);

      expect(placeholder, findsNothing);
      expect(avatars.requested, hasLength(2));
    });

    group('cached on disk', () {
      /// Loads [flutterAvatar] once, then forgets the decoded image, as
      /// after an app restart.
      Future<void> seenBefore(WidgetTester tester) async {
        await pumpAvatar(tester, flutterAvatar);
        await loadImages(tester);
        await tester.pumpWidget(const SizedBox());
        imageCache
          ..clear()
          ..clearLiveImages();
      }

      testWidgets('shows an avatar seen before without downloading it', (
        tester,
      ) async {
        await seenBefore(tester);
        avatars.requested.clear();

        await pumpAvatar(tester, flutterAvatar);
        await loadImages(tester);

        expect(placeholder, findsNothing);
        expect(avatars.requested, isEmpty);
      });

      // The list's small avatar stands in for the detail screen's large one.
      testWidgets('shows a smaller size seen before while offline', (
        tester,
      ) async {
        await seenBefore(tester);
        avatars.offline = true;

        await pumpAvatar(tester, flutterAvatar, size: 96);
        await loadImages(tester);

        expect(placeholder, findsNothing);
      });

      testWidgets('shows an avatar seen before while offline', (tester) async {
        await seenBefore(tester);
        avatars.offline = true;

        await pumpAvatar(tester, flutterAvatar);
        await loadImages(tester);

        expect(placeholder, findsNothing);
      });
    });

    testWidgets('is a 40 pixel circle', (tester) async {
      await pumpAvatar(tester, null);

      expect(tester.getSize(find.byType(RepoAvatar)), const Size.square(40));
    });

    group('fetches and decodes only the pixels it shows', () {
      testWidgets('asks GitHub for an avatar of that size', (tester) async {
        await pumpAvatar(tester, flutterAvatar);
        await loadImages(tester);

        expect(avatars.requested.toSet(), {
          Uri.parse(
            'https://avatars.githubusercontent.com/u/14101776?v=4&s=80',
          ),
        });
      });

      testWidgets('decodes the image at that size', (tester) async {
        await pumpAvatar(tester, flutterAvatar);

        final image = tester.widget<Image>(find.byType(Image)).image;
        expect(
          image,
          isA<ResizeImage>()
              .having((image) => image.width, 'width', 80)
              .having((image) => image.height, 'height', 80),
        );
      });

      // Only GitHub's avatar host is known to accept the size parameter.
      testWidgets('leaves other URLs unchanged', (tester) async {
        await pumpAvatar(tester, 'https://example.com/a.png?v=4');
        await loadImages(tester);

        expect(avatars.requested.toSet(), {
          Uri.parse('https://example.com/a.png?v=4'),
        });
      });
    });
  });
}
