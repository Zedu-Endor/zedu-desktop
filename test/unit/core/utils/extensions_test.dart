import 'package:zedu/core/core.dart';

import '../../../helpers/helpers.dart';

void main() {
  group('CountLabelX.countLabel', () {
    test('uses the singular for one', () {
      expect(1.countLabel('member'), '1 member');
    });

    test('uses the plural for zero and more than one', () {
      expect(0.countLabel('member'), '0 members');
      expect(5.countLabel('member'), '5 members');
    });

    test('uses an irregular plural when given', () {
      expect(2.countLabel('person', 'people'), '2 people');
      expect(1.countLabel('person', 'people'), '1 person');
    });
  });

  group('CountLabelX.unreadBadgeText', () {
    test('formats counts under or equal to 99 as numbers', () {
      expect(0.unreadBadgeText, '0');
      expect(1.unreadBadgeText, '1');
      expect(99.unreadBadgeText, '99');
    });

    test('formats counts greater than 99 as 99+', () {
      expect(100.unreadBadgeText, '99+');
      expect(250.unreadBadgeText, '99+');
      expect(1351.unreadBadgeText, '99+');
    });
  });
}
