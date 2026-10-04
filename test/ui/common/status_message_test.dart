import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:github_repo_viewer/ui/common/status_message.dart';

void main() {
  group('StatusMessage', () {
    Future<void> pumpMessage(WidgetTester tester, StatusMessage message) {
      return tester.pumpWidget(MaterialApp(home: Scaffold(body: message)));
    }

    testWidgets('shows the icon, title, message and action', (tester) async {
      var pressed = 0;
      await pumpMessage(
        tester,
        StatusMessage(
          icon: Icons.search,
          title: 'Search GitHub',
          message: 'Find repositories by keyword.',
          action: FilledButton(
            onPressed: () => pressed++,
            child: const Text('Retry'),
          ),
        ),
      );

      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.text('Search GitHub'), findsOneWidget);
      expect(find.text('Find repositories by keyword.'), findsOneWidget);

      await tester.tap(find.text('Retry'));

      expect(pressed, 1);
    });

    testWidgets('shows only a title when that is all it has', (tester) async {
      await pumpMessage(
        tester,
        const StatusMessage(icon: Icons.search, title: 'Search GitHub'),
      );

      expect(find.byType(Text), findsOneWidget);
      expect(find.byType(ButtonStyleButton), findsNothing);
    });

    // e.g. on a small phone with the keyboard open.
    testWidgets('scrolls instead of overflowing in a short space', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 80,
              child: StatusMessage(
                icon: Icons.search,
                title: 'Search GitHub',
                message: 'Find repositories by keyword. ' * 5,
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(Scrollable), findsOneWidget);
    });
  });
}
