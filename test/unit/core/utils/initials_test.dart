import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/utils/initials.dart';

void main() {
  group('avatarInitial', () {
    test('upper-cases the first letter', () {
      expect(avatarInitial('ada'), 'A');
      expect(avatarInitial('Émile'), 'É');
    });

    test('keeps an emoji whole instead of half a surrogate pair', () {
      expect(avatarInitial('😀 Ada'), '😀');
      expect(avatarInitial('🚀launch'), '🚀');
    });

    test('keeps a flag, a joined emoji and a skin tone whole', () {
      expect(avatarInitial('🇳🇬 Lagos'), '🇳🇬');
      expect(avatarInitial('👩‍💻 dev'), '👩‍💻');
      expect(avatarInitial('👍🏽 yes'), '👍🏽');
    });

    test('keeps a letter with a combining accent whole', () {
      expect(avatarInitial('émile'), 'É');
    });

    test('ignores leading spaces', () {
      expect(avatarInitial('  bola'), 'B');
    });

    test('falls back when there is no name', () {
      expect(avatarInitial(''), '?');
      expect(avatarInitial('   '), '?');
      expect(avatarInitial(null), '?');
      expect(avatarInitial('', fallback: '#'), '#');
    });
  });
}
