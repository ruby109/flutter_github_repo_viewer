import 'package:flutter_test/flutter_test.dart';

import 'package:github_repo_viewer/data/github/search_page.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/github_json.dart';

void main() {
  group('SearchPage', () {
    List<Map<String, Object?>> repos(int count) => [
      for (var i = 1; i <= count; i++) repoJson(id: i, fullName: 'owner/r$i'),
    ];

    SearchPage parse({
      required int totalCount,
      required int itemCount,
      required int page,
      int perPage = 30,
    }) {
      return SearchPage.fromJson(
        searchJson(totalCount: totalCount, items: repos(itemCount)),
        page: page,
        perPage: perPage,
      );
    }

    test('parses items and total_count', () {
      final result = SearchPage.fromJson(
        searchJson(
          totalCount: 2,
          items: [
            repoJson(id: 1, fullName: 'a/one'),
            repoJson(id: 2, fullName: 'b/two'),
          ],
        ),
        page: 1,
        perPage: 30,
      );

      expect(result.items.map((repo) => repo.fullName), ['a/one', 'b/two']);
      expect(result.totalCount, 2);
    });

    test('parses a real Search API response', () {
      final result = SearchPage.fromJson(searchFixture(), page: 1, perPage: 10);

      expect(result.items, hasLength(10));
      expect(result.items.first.fullName, 'flutter/flutter');
      expect(
        result.items.first.owner?.avatarUrl,
        'https://avatars.githubusercontent.com/u/14101776?v=4',
      );
      expect(result.totalCount, greaterThan(SearchPage.maxResults));
      expect(result.hasMore, isTrue);
    });

    group('hasMore', () {
      test('is true when results remain after this page', () {
        expect(parse(totalCount: 100, itemCount: 30, page: 1).hasMore, isTrue);
      });

      test('is false on the last page', () {
        expect(parse(totalCount: 100, itemCount: 10, page: 4).hasMore, isFalse);
      });

      test('is false when total_count fits exactly in the pages so far', () {
        expect(parse(totalCount: 60, itemCount: 30, page: 2).hasMore, isFalse);
      });

      test('is false when there are no results', () {
        expect(parse(totalCount: 0, itemCount: 0, page: 1).hasMore, isFalse);
      });

      // The Search API returns at most 1000 results; asking past them is a
      // 422 error, however large total_count is.
      test('stops at the 1000-result search limit', () {
        expect(
          parse(totalCount: 5000, itemCount: 30, page: 33).hasMore,
          isTrue,
        );
        expect(
          parse(totalCount: 5000, itemCount: 30, page: 34).hasMore,
          isFalse,
        );
      });

      // Guards against requesting empty pages forever if total_count
      // overstates what GitHub actually returns.
      test('is false when a page comes back empty', () {
        expect(parse(totalCount: 100, itemCount: 0, page: 2).hasMore, isFalse);
      });
    });

    group('throws FormatException', () {
      final invalidCases = <String, void Function(Map<String, Object?>)>{
        'when items is missing': (json) => json.remove('items'),
        'when items is not a list': (json) => json['items'] = 'none',
        'when total_count is missing': (json) => json.remove('total_count'),
        'when an item is not an object': (json) => json['items'] = [42],
        'when an item is invalid': (json) =>
            json['items'] = [repoJson()..remove('id')],
      };

      invalidCases.forEach((description, corrupt) {
        test(description, () {
          final json = searchJson(totalCount: 1, items: [repoJson()]);
          corrupt(json);

          expect(
            () => SearchPage.fromJson(json, page: 1, perPage: 30),
            throwsFormatException,
          );
        });
      });
    });
  });
}
