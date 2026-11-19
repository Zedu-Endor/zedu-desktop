import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/people/domain/entities/org_member.dart';

void main() {
  group('OrgMember.initial', () {
    test('returns uppercase first letter for standard English names', () {
      const member = OrgMember(id: '1', name: 'alice');
      expect(member.initial, 'A');
    });

    test('falls back to username or email if name is empty', () {
      const member1 = OrgMember(id: '1', username: 'bob');
      expect(member1.initial, 'B');

      const member2 = OrgMember(id: '2', email: 'charlie@example.com');
      expect(member2.initial, 'C');
    });

    test(
      'preserves emojis and complex graphemes without UTF-16 surrogate corruption',
      () {
        const emojiMember = OrgMember(id: '1', name: '😀 Ada');
        expect(emojiMember.initial, '😀');

        const rocketMember = OrgMember(id: '2', name: '🚀 Rocket');
        expect(rocketMember.initial, '🚀');

        const flagMember = OrgMember(id: '3', name: '🇳🇬 Nigeria Team');
        expect(flagMember.initial, '🇳🇬');

        const technologistMember = OrgMember(id: '4', name: '👩‍💻 Coder');
        expect(technologistMember.initial, '👩‍💻');
      },
    );

    test('handles whitespace and fallback', () {
      const emptyMember = OrgMember(id: '1');
      expect(
        emptyMember.initial,
        'U',
      ); // Display name falls back to 'Unknown' -> 'U'
    });
  });
}
