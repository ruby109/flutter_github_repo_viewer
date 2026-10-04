import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:github_repo_viewer/data/github/github_providers.dart';
import 'package:github_repo_viewer/data/preferences/shared_preferences_provider.dart';
import 'package:github_repo_viewer/state/search_query_notifier.dart';
import 'package:github_repo_viewer/ui/search/search_results_view.dart';
import 'package:github_repo_viewer/ui/search/search_screen.dart';

import '../../helpers/github_json.dart';
import '../../helpers/preferences.dart';

void main() {
  group('SearchScreen', () {
    Future<ProviderContainer> pumpScreen(WidgetTester tester) async {
      final container = ProviderContainer.test(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await inMemoryPreferences(),
          ),
          httpClientProvider.overrideWithValue(
            MockClient(
              (_) async => http.Response(
                jsonEncode(searchJson(totalCount: 0, items: [])),
                200,
              ),
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: SearchScreen(onRepoTap: (_) {})),
        ),
      );
      return container;
    }

    final field = find.byType(TextField);
    final home = find.text(SearchScreen.homeTitle);
    final clearButton = find.byTooltip('Clear');

    Future<void> search(WidgetTester tester, String text) async {
      await tester.enterText(field, text);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
    }

    String? shownQuery(WidgetTester tester) {
      final views = find.byType(SearchResultsView);
      if (views.evaluate().isEmpty) return null;
      return tester.widget<SearchResultsView>(views).query;
    }

    testWidgets('shows the home state with an empty search box', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(home, findsOneWidget);
      expect(shownQuery(tester), isNull);
    });

    testWidgets('searches for the text when search is pressed', (tester) async {
      final container = await pumpScreen(tester);

      await search(tester, '  flutter ');

      expect(container.read(searchQueryProvider), 'flutter');
      expect(shownQuery(tester), 'flutter');
      expect(home, findsNothing);
    });

    // Unauthenticated clients get 10 searches a minute.
    testWidgets('does not search while typing', (tester) async {
      final container = await pumpScreen(tester);

      await tester.enterText(field, 'flutter');
      await tester.pump();

      expect(container.read(searchQueryProvider), isEmpty);
      expect(home, findsOneWidget);
    });

    testWidgets('stays home when searching for blank text', (tester) async {
      await pumpScreen(tester);

      await search(tester, '   ');

      expect(home, findsOneWidget);
    });

    testWidgets('returns home when the text is deleted', (tester) async {
      final container = await pumpScreen(tester);
      await search(tester, 'flutter');

      await tester.enterText(field, '');
      await tester.pump();

      expect(container.read(searchQueryProvider), isEmpty);
      expect(home, findsOneWidget);
    });

    group('clear button', () {
      testWidgets('is shown only when there is text', (tester) async {
        await pumpScreen(tester);

        expect(clearButton, findsNothing);

        await tester.enterText(field, 'flutter');
        await tester.pump();

        expect(clearButton, findsOneWidget);
      });

      testWidgets('empties the box and returns home', (tester) async {
        final container = await pumpScreen(tester);
        await search(tester, 'flutter');

        await tester.tap(clearButton);
        await tester.pump();

        expect(tester.widget<TextField>(field).controller?.text, isEmpty);
        expect(container.read(searchQueryProvider), isEmpty);
        expect(home, findsOneWidget);
      });
    });

    testWidgets('a new search replaces the previous one', (tester) async {
      await pumpScreen(tester);
      await search(tester, 'flutter');

      await search(tester, 'riverpod');

      expect(shownQuery(tester), 'riverpod');
    });
  });
}
