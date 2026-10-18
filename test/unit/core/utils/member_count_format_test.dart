import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';

void main() {
  group('formatMemberCount', () {
    test('uses the singular for exactly one member', () {
      expect(formatMemberCount(1), '1 member');
    });

    test('uses the plural for zero and more than one', () {
      expect(formatMemberCount(0), '0 members');
      expect(formatMemberCount(2), '2 members');
      expect(formatMemberCount(1906), '1906 members');
    });
  });
}
