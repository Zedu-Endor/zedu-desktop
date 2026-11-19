import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

void main() {
  DmConversation conversation(String name, {required int unreadCount}) {
    return DmConversation(
      channelId: name.toLowerCase(),
      username: name,
      participantId: 'participant-$name',
      previewMessage: 'Hello',
      unreadCount: unreadCount,
      previewThreads: const [],
    );
  }

  group('DmConversation.isUnread', () {
    test('is true when the conversation has unread messages', () {
      expect(conversation('Ada', unreadCount: 3).isUnread, isTrue);
    });

    test('is false when everything has been read', () {
      expect(conversation('Ada', unreadCount: 0).isUnread, isFalse);
    });
  });

  group('unreadConversations', () {
    test('keeps only conversations with unread messages', () {
      final result = unreadConversations([
        conversation('Ada', unreadCount: 2),
        conversation('Bola', unreadCount: 0),
        conversation('Chidi', unreadCount: 1),
      ]);

      expect(result.map((c) => c.displayName), ['Ada', 'Chidi']);
    });

    test('leaves the incoming order alone so the caller keeps its sort', () {
      final pinned = conversation('Zara', unreadCount: 1);
      final recent = conversation('Ada', unreadCount: 1);

      final result = unreadConversations([pinned, recent]);

      expect(result.map((c) => c.displayName), ['Zara', 'Ada']);
    });

    test('is empty when nothing is unread', () {
      final result = unreadConversations([
        conversation('Ada', unreadCount: 0),
        conversation('Bola', unreadCount: 0),
      ]);

      expect(result, isEmpty);
    });
  });
}
