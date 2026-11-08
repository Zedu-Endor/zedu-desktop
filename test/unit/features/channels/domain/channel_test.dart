import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

void main() {
  group('Channel.fromJson counts (#4131)', () {
    test('reads whole-number counts', () {
      final channel = Channel.fromJson({
        'id': 'c1',
        'name': 'general',
        'unread_count': 3,
        'members_count': 12,
      });

      expect(channel.unreadCount, 3);
      expect(channel.membersCount, 12);
    });

    test('reads counts sent as decimals instead of throwing', () {
      final channel = Channel.fromJson({
        'id': 'c1',
        'name': 'general',
        'unread_count': 3.0,
        'members_count': 12.0,
      });

      expect(channel.unreadCount, 3);
      expect(channel.membersCount, 12);
    });

    test('defaults missing counts to 0', () {
      final channel = Channel.fromJson({'id': 'c1', 'name': 'general'});

      expect(channel.unreadCount, 0);
      expect(channel.membersCount, 0);
    });
  });
}
