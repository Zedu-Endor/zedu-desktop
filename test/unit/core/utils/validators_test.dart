import 'package:zedu/core/core.dart';

import '../../../helpers/helpers.dart';

// validateEmail takes a BuildContext but never reads it.
class _MockBuildContext extends Mock implements BuildContext {}

void main() {
  final context = _MockBuildContext();

  group('Validators.validateEmail', () {
    test('accepts a valid email', () {
      expect(Validators.validateEmail(context, 'you@example.com'), isNull);
    });

    test('accepts an email with leading or trailing spaces', () {
      expect(Validators.validateEmail(context, 'you@example.com '), isNull);
      expect(Validators.validateEmail(context, ' you@example.com'), isNull);
      expect(Validators.validateEmail(context, '  you@example.com  '), isNull);
      expect(Validators.validateEmail(context, 'you@example.com\t'), isNull);
    });

    test('requires an email when the field is empty or only whitespace', () {
      expect(Validators.validateEmail(context, null), 'Email is required');
      expect(Validators.validateEmail(context, ''), 'Email is required');
      expect(Validators.validateEmail(context, '   '), 'Email is required');
    });

    test('rejects invalid emails', () {
      for (final email in [
        'you@',
        'you example.com',
        'you@example',
        'you @example.com',
        '@example.com',
      ]) {
        expect(
          Validators.validateEmail(context, email),
          'Please enter a valid email',
          reason: email,
        );
      }
    });
  });

  group('Validators.normalizeChannelName', () {
    test('converts uppercase to lowercase and trims whitespace', () {
      expect(Validators.normalizeChannelName('  Project X  '), 'project-x');
    });

    test('collapses runs of tabs and spaces to single hyphens', () {
      expect(
        Validators.normalizeChannelName('team\t\tplan   budget'),
        'team-plan-budget',
      );
    });
  });

  group('Validators.validateChannelName', () {
    test('requires channel name when null, empty or whitespace', () {
      expect(Validators.validateChannelName(null), 'Channel name is required');
      expect(Validators.validateChannelName(''), 'Channel name is required');
      expect(Validators.validateChannelName('   '), 'Channel name is required');
    });

    test('accepts valid channel names up to 40 characters', () {
      expect(Validators.validateChannelName('general'), isNull);
      expect(Validators.validateChannelName('a' * 40), isNull);
    });

    test('rejects channel names longer than 40 characters', () {
      expect(
        Validators.validateChannelName('a' * 41),
        'Channel name must be 40 characters or fewer',
      );
    });
  });
}
