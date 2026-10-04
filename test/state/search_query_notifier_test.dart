import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:github_repo_viewer/state/search_query_notifier.dart';

void main() {
  group('SearchQueryNotifier', () {
    test('starts with no query', () {
      final container = ProviderContainer.test();

      expect(container.read(searchQueryProvider), '');
    });

    test('submits the trimmed text', () {
      final container = ProviderContainer.test();

      container
          .read(searchQueryProvider.notifier)
          .submit('  flutter riverpod ');

      expect(container.read(searchQueryProvider), 'flutter riverpod');
    });

    test('submitting blank text clears the query', () {
      final container = ProviderContainer.test();
      final notifier = container.read(searchQueryProvider.notifier)
        ..submit('flutter');

      notifier.submit('   ');

      expect(container.read(searchQueryProvider), '');
    });

    test('clear removes the query', () {
      final container = ProviderContainer.test();
      final notifier = container.read(searchQueryProvider.notifier)
        ..submit('flutter');

      notifier.clear();

      expect(container.read(searchQueryProvider), '');
    });
  });
}
