import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/user_profile/domain/entities/bulk_invitation.dart';

void main() {
  test('normalizes and deduplicates mixed separators preserving order', () {
    expect(
      BulkInvitation.addresses(
        ' Ada@Example.com; bob@example.com\nada@example.com ',
      ),
      ['ada@example.com', 'bob@example.com'],
    );
  });
  test('rejects invalid addresses and accepts plus addressing', () {
    expect(BulkInvitation.valid('a+b@example.com'), isTrue);
    for (final email in ['a', 'a@', '@example.com', 'a b@example.com']) {
      expect(BulkInvitation.valid(email), isFalse);
    }
  });
}
