import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:github_repo_viewer/main.dart';
import 'package:github_repo_viewer/ui/shell/home_shell.dart';

void main() {
  group('MyApp', () {
    testWidgets('opens on the home shell', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: MyApp()));

      expect(find.byType(HomeShell), findsOneWidget);
    });
  });
}
