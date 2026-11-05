import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

void main() {
  group('DmPreviewThread.fromJson resilience', () {
    test('parses ISO-8601 created_at string successfully', () {
      final json = <String, dynamic>{
        'thread_id': 'th-1',
        'message': 'Hello world',
        'user_id': 'u-1',
        'username': 'Alice',
        'created_at': '2026-11-05T14:00:00.000Z',
        'message_count': 3,
      };

      final thread = DmPreviewThread.fromJson(json);
      expect(thread.threadId, 'th-1');
      expect(thread.message, 'Hello world');
      expect(
        thread.createdAt.isUtc ? thread.createdAt : thread.createdAt.toUtc(),
        DateTime.utc(2026, 11, 5, 14, 0),
      );
    });

    test(
      'falls back safely to current time when created_at is empty string without throwing',
      () {
        final before = DateTime.now().subtract(const Duration(seconds: 1));
        final json = <String, dynamic>{
          'thread_id': 'th-2',
          'message': 'Empty date thread',
          'user_id': 'u-2',
          'username': 'Bob',
          'created_at': '',
          'message_count': 1,
        };

        final thread = DmPreviewThread.fromJson(json);
        final after = DateTime.now().add(const Duration(seconds: 1));

        expect(thread.threadId, 'th-2');
        expect(thread.createdAt.isAfter(before), isTrue);
        expect(thread.createdAt.isBefore(after), isTrue);
      },
    );

    test(
      'falls back safely to current time when created_at is malformed text without throwing',
      () {
        final before = DateTime.now().subtract(const Duration(seconds: 1));
        final json = <String, dynamic>{
          'thread_id': 'th-3',
          'message': 'Malformed date thread',
          'user_id': 'u-3',
          'username': 'Charlie',
          'created_at': 'invalid-date-format-abc',
          'message_count': 0,
        };

        final thread = DmPreviewThread.fromJson(json);
        final after = DateTime.now().add(const Duration(seconds: 1));

        expect(thread.threadId, 'th-3');
        expect(thread.createdAt.isAfter(before), isTrue);
        expect(thread.createdAt.isBefore(after), isTrue);
      },
    );

    test('falls back safely to current time when created_at is null', () {
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      final json = <String, dynamic>{
        'thread_id': 'th-4',
        'message': 'Null date thread',
        'user_id': 'u-4',
        'username': 'Dave',
        'created_at': null,
      };

      final thread = DmPreviewThread.fromJson(json);
      final after = DateTime.now().add(const Duration(seconds: 1));

      expect(thread.threadId, 'th-4');
      expect(thread.createdAt.isAfter(before), isTrue);
      expect(thread.createdAt.isBefore(after), isTrue);
    });

    test(
      'parses numeric epoch timestamp in seconds without throwing TypeError',
      () {
        const epochSeconds = 1730819230; // 2024-11-05 approx
        final expectedDate = DateTime.fromMillisecondsSinceEpoch(
          epochSeconds * 1000,
        ).toLocal();

        final json = <String, dynamic>{
          'thread_id': 'th-5',
          'message': 'Epoch date thread',
          'user_id': 'u-5',
          'username': 'Eve',
          'created_at': epochSeconds,
        };

        final thread = DmPreviewThread.fromJson(json);
        expect(thread.threadId, 'th-5');
        expect(thread.createdAt, expectedDate);
      },
    );

    test(
      'parses numeric string epoch timestamp without throwing FormatException',
      () {
        const epochSeconds = 1730819230;
        final expectedDate = DateTime.fromMillisecondsSinceEpoch(
          epochSeconds * 1000,
        ).toLocal();

        final json = <String, dynamic>{
          'thread_id': 'th-6',
          'message': 'Epoch string date thread',
          'user_id': 'u-6',
          'username': 'Frank',
          'created_at': '$epochSeconds',
        };

        final thread = DmPreviewThread.fromJson(json);
        expect(thread.threadId, 'th-6');
        expect(thread.createdAt, expectedDate);
      },
    );
  });

  group('DmConversation.fromJson resilience with bad thread dates', () {
    test(
      'successfully parses conversation even when preview thread has empty or malformed created_at',
      () {
        final json = <String, dynamic>{
          'channel_id': 'ch-1',
          'username': 'Grace',
          'participant_id': 'u-7',
          'preview_message': 'Recent message',
          'unread_count': 2,
          'preview_thread': [
            {
              'thread_id': 'th-bad-1',
              'message': 'Broken date thread',
              'user_id': 'u-7',
              'username': 'Grace',
              'created_at': '',
            },
            {
              'thread_id': 'th-good-1',
              'message': 'Good date thread',
              'user_id': 'u-7',
              'username': 'Grace',
              'created_at': '2026-11-05T14:30:00.000Z',
            },
          ],
        };

        final conversation = DmConversation.fromJson(json);
        expect(conversation.channelId, 'ch-1');
        expect(conversation.username, 'Grace');
        expect(conversation.previewThreads.length, 2);
        expect(conversation.previewThreads.first.threadId, 'th-bad-1');
        expect(conversation.hasActivity, isTrue);
      },
    );
  });
}
