import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

void main() {
  DmConversation conversation(
    String name, {
    required DateTime at,
    String? channelId,
  }) {
    return DmConversation(
      channelId: channelId ?? name.toLowerCase(),
      username: name,
      participantId: 'participant-$name',
      previewMessage: 'Hello',
      unreadCount: 0,
      previewThreads: [
        DmPreviewThread(
          threadId: 'thread-$name',
          message: 'Hello',
          userId: 'user-$name',
          username: name,
          createdAt: at,
        ),
      ],
    );
  }

  List<DmConversation> sorted(
    DmSort sort,
    List<DmConversation> conversations, {
    Set<String> pinned = const {},
  }) {
    return [...conversations]..sort(
      (a, b) => sort.compare(
        a,
        b,
        aPinned: pinned.contains(a.channelId),
        bPinned: pinned.contains(b.channelId),
      ),
    );
  }

  final oldest = DateTime(2026, 1, 1, 9);
  final middle = DateTime(2026, 1, 1, 10);
  final newest = DateTime(2026, 1, 1, 11);

  group('DmSort.alphabetical', () {
    test('orders conversations by name regardless of activity', () {
      final result = sorted(DmSort.alphabetical, [
        conversation('Zara', at: newest),
        conversation('Ada', at: oldest),
        conversation('Bola', at: middle),
      ]);

      expect(result.map((c) => c.displayName), ['Ada', 'Bola', 'Zara']);
    });

    test('ignores case when comparing names', () {
      final result = sorted(DmSort.alphabetical, [
        conversation('beta', at: oldest),
        conversation('Alpha', at: newest),
      ]);

      expect(result.map((c) => c.displayName), ['Alpha', 'beta']);
    });

    test('keeps pinned conversations above the alphabetical ones', () {
      final result = sorted(
        DmSort.alphabetical,
        [
          conversation('Ada', at: oldest),
          conversation('Zara', at: middle),
          conversation('Bola', at: newest),
        ],
        pinned: {'zara'},
      );

      expect(result.map((c) => c.displayName), ['Zara', 'Ada', 'Bola']);
    });

    test('falls back to recent activity when names match', () {
      final older = conversation('Ada', at: oldest, channelId: 'ada-old');
      final newer = conversation('Ada', at: newest, channelId: 'ada-new');

      final result = sorted(DmSort.alphabetical, [older, newer]);

      expect(result.map((c) => c.channelId), ['ada-new', 'ada-old']);
    });
  });

  group('DmSort.recentActivity', () {
    test('keeps the newest conversation first', () {
      final result = sorted(DmSort.recentActivity, [
        conversation('Ada', at: oldest),
        conversation('Zara', at: newest),
        conversation('Bola', at: middle),
      ]);

      expect(result.map((c) => c.displayName), ['Zara', 'Bola', 'Ada']);
    });

    test('keeps pinned conversations first', () {
      final result = sorted(
        DmSort.recentActivity,
        [conversation('Ada', at: newest), conversation('Zara', at: oldest)],
        pinned: {'zara'},
      );

      expect(result.map((c) => c.displayName), ['Zara', 'Ada']);
    });
  });
}
