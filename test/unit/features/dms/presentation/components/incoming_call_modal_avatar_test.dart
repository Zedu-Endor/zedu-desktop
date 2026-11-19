import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';

/// Test to verify that avatar initials correctly handle UTF-16 surrogate pairs
/// and multi-codepoint characters (including emojis and accented letters)
/// as used by IncomingCallModal.
void main() {
  group('IncomingCallModal Avatar Initials (avatarInitial)', () {
    test('ASCII name returns uppercase first letter', () {
      expect(avatarInitial('John'), 'J');
      expect(avatarInitial('Bob'), 'B');
      expect(avatarInitial('Alice'), 'A');
    });

    test('Accented letter returns uppercase first grapheme cluster', () {
      expect(avatarInitial('Émile'), 'É');
      expect(avatarInitial('José'), 'J');
      expect(avatarInitial('Anaïs'), 'A');
      expect(avatarInitial('Zoë'), 'Z');
    });

    test('Emoji returns the full grapheme cluster as the initial', () {
      expect(avatarInitial('😀YOY'), '😀');
      expect(avatarInitial('👨‍👩‍👧‍👦 YOY'), '👨‍👩‍👧‍👦');
      expect(avatarInitial('🙏 User'), '🙏');
    });

    test('Mixed emoji and ASCII returns the first grapheme cluster', () {
      expect(avatarInitial('😀 John'), '😀');
      expect(avatarInitial('👋Zoe'), '👋');
      expect(avatarInitial('❤️ Zoe'), '❤️');
    });

    test('Whitespace-only name returns fallback ?', () {
      expect(avatarInitial('   '), '?');
      expect(avatarInitial('\t\n'), '?');
    });

    test('Null name returns fallback ?', () {
      expect(avatarInitial(null), '?');
    });

    test('Empty string returns fallback ?', () {
      expect(avatarInitial(''), '?');
    });

    test('Multiple spaces trim before extracting initial', () {
      expect(avatarInitial('  Mary  '), 'M');
      expect(avatarInitial('   Bob   '), 'B');
    });

    test('Combination of emoji and accented letters', () {
      expect(avatarInitial('😍 Ana'), '😍');
      expect(avatarInitial('👩‍🦰 Zoë'), '👩‍🦰');
    });
  });
}
