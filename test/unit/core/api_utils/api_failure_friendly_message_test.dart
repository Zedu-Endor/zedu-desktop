import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';

void main() {
  group('ApiFailure.friendlyMessage hides internals (Ziki #2704)', () {
    test('a parsing failure does not leak the exception text', () {
      final failure = ApiFailure.fromParsingError(
        TypeError(),
        path: '/profile',
      );

      expect(failure.friendlyMessage, isNot(contains('Parsing error')));
      expect(failure.friendlyMessage, isNot(contains('TypeError')));
      expect(failure.friendlyMessage, isNot(contains('Could not parse')));
      expect(
        failure.friendlyMessage,
        'We could not read the response from the server. Please try again.',
      );
    });

    test('an unknown failure does not leak the exception text', () {
      final failure = ApiFailure.unknown(StateError('boom'));

      expect(failure.friendlyMessage, isNot(contains('Unknown error')));
      expect(failure.friendlyMessage, isNot(contains('boom')));
      expect(failure.friendlyMessage, contains('Something went wrong'));
    });

    test('the raw detail is still kept for logs', () {
      final failure = ApiFailure.fromParsingError(TypeError(), path: '/x');

      expect(failure.message, contains('Could not parse response'));
      expect(failure.kind, ApiFailureKind.parsing);
    });
  });
}
