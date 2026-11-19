import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

Map<String, dynamic> _json({String? lastReadAt}) => {
  'channel_id': 'dm-1',
  'username': 'Ada',
  'participant_id': 'user-1',
  'preview_message': '',
  'last_read_at': lastReadAt,
};

void main() {
  group('DmConversation.lastReadAt', () {
    test('treats the Go zero timestamp as no activity', () {
      final conversation = DmConversation.fromJson(
        _json(lastReadAt: '0001-01-01T00:00:00Z'),
      );

      expect(conversation.lastReadAt, isNull);
      expect(conversation.hasActivity, isFalse);
      expect(
        conversation.lastActivityAt,
        DateTime.fromMillisecondsSinceEpoch(0),
      );
    });

    test('treats a null last_read_at as no activity', () {
      final conversation = DmConversation.fromJson(_json());

      expect(conversation.lastReadAt, isNull);
      expect(conversation.hasActivity, isFalse);
    });

    test('treats the 1970 placeholder as no activity', () {
      final conversation = DmConversation.fromJson(
        _json(lastReadAt: '1970-01-01T00:00:00Z'),
      );

      expect(conversation.lastReadAt, isNull);
      expect(conversation.hasActivity, isFalse);
    });

    test('keeps a real last read timestamp', () {
      final conversation = DmConversation.fromJson(
        _json(lastReadAt: '2026-11-05T08:00:00Z'),
      );

      expect(conversation.lastReadAt, isNotNull);
      expect(conversation.lastReadAt!.toUtc(), DateTime.utc(2026, 11, 5, 8));
      expect(conversation.hasActivity, isTrue);
    });
  });
}
