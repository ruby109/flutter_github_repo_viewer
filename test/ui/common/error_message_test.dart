import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:github_repo_viewer/data/github/github_api_exception.dart';
import 'package:github_repo_viewer/ui/common/error_message.dart';

void main() {
  group('describeError', () {
    /// Describes [error] in an app using 12- or 24-hour time.
    Future<ErrorMessage> describe(
      WidgetTester tester,
      Object error, {
      bool alwaysUse24HourFormat = false,
    }) async {
      late ErrorMessage description;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(alwaysUse24HourFormat: alwaysUse24HourFormat),
            child: Builder(
              builder: (context) {
                description = describeError(context, error);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      return description;
    }

    group('rate limiting', () {
      final retryAt = DateTime(2026, 10, 4, 14, 5);

      testWidgets('says when to try again', (tester) async {
        final description = await describe(
          tester,
          RateLimitException(retryAt: retryAt),
        );

        expect(description.title, 'Too many requests');
        expect(description.message, contains('Try again after 2:05 PM.'));
      });

      testWidgets('uses the 24-hour clock when the device does', (
        tester,
      ) async {
        final description = await describe(
          tester,
          RateLimitException(retryAt: retryAt),
          alwaysUse24HourFormat: true,
        );

        expect(description.message, contains('Try again after 14:05.'));
      });

      testWidgets('suggests waiting when GitHub gave no time', (tester) async {
        final description = await describe(tester, const RateLimitException());

        expect(description.message, contains('Wait a minute and try again.'));
      });
    });

    final descriptions = <String, (Object, String, String)>{
      'no connection': (
        NetworkException(Exception('offline')),
        'No connection',
        'Check your internet connection',
      ),
      'a deleted repository': (
        const NotFoundException(),
        'Not found',
        'no longer exists',
      ),
      'an unexpected status': (
        const HttpStatusException(500),
        'Something went wrong',
        'GitHub answered with an error (500)',
      ),
      'an unreadable response': (
        MalformedResponseException(const FormatException('bad')),
        'Something went wrong',
        "couldn't be read",
      ),
      'any other error': (
        StateError('bug'),
        'Something went wrong',
        'Try again',
      ),
    };

    descriptions.forEach((name, expected) {
      final (error, title, message) = expected;

      testWidgets('describes $name', (tester) async {
        final description = await describe(tester, error);

        expect(description.title, title);
        expect(description.message, contains(message));
      });
    });

    testWidgets('gives each kind of error its own icon', (tester) async {
      final icons = {
        for (final (error, _, _) in descriptions.values)
          (await describe(tester, error)).icon,
        (await describe(tester, const RateLimitException())).icon,
      };

      // Unexpected statuses, unreadable responses and other errors share one.
      expect(icons, hasLength(4));
    });
  });
}
