import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

void main() {
  group('DmConversation.fromJson', () {
    test(
      'does not fall back to thread_count when unread_count is null or missing',
      () {
        final json = {
          'id': 'conv-1',
          'channel_id': 'ch-1',
          'participant_id': 'user-1',
          'participant_name': 'Alice',
          'thread_count': 12,
          // unread_count omitted
        };

        final conv = DmConversation.fromJson(json);

        expect(conv.threadCount, 12);
        expect(conv.unreadCount, 0);
      },
    );

    test('correctly parses unread_count when provided', () {
      final json = {
        'id': 'conv-2',
        'channel_id': 'ch-2',
        'participant_id': 'user-2',
        'participant_name': 'Bob',
        'thread_count': 10,
        'unread_count': 4,
      };

      final conv = DmConversation.fromJson(json);

      expect(conv.threadCount, 10);
      expect(conv.unreadCount, 4);
    });
  });
}
