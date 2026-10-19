import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';

void main() {
  group('avatarInitials', () {
    test('uses the first letters of a name', () {
      expect(avatarInitials('Ada'), 'A');
      expect(avatarInitials('Ada Lovelace', count: 2), 'AD');
    });

    test('trims leading space instead of painting a blank initial', () {
      expect(avatarInitials(' John'), 'J');
      expect(avatarInitials('  Jo', count: 2), 'JO');
    });

    test('does not throw when the name is empty or whitespace', () {
      expect(avatarInitials(''), '?');
      expect(avatarInitials('   '), '?');
      expect(avatarInitials(null), '?');
    });
  });

  group('avatarInitialsFrom', () {
    test('skips a blank name and uses the next candidate', () {
      expect(avatarInitialsFrom(['', 'ada@zedu.chat']), 'A');
      expect(avatarInitialsFrom([null, '  ']), '?');
    });
  });
}
