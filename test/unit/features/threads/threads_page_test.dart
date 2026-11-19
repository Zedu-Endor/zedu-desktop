import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/threads/domain/inbox_thread.dart';

Map<String, dynamic> discussion(String id) => {
  'thread_id': id,
  'channel_name': 'engineering',
  'thread_messages': [
    {
      'thread_id': id,
      'channels_id': 'channel-1',
      'username': 'Grace',
      'message': 'Release discussion',
    },
  ],
};

void main() {
  test('parses the current object payload and unread count', () {
    final page = ThreadsPage.fromJson({
      'data': {
        'threads': [discussion('a')],
        'unseen_thread_count': 3,
      },
      'pagination': {'total_pages_count': 2},
    }, 1);
    expect(page.threads.single.id, 'a');
    expect(page.threads.single.channelId, 'channel-1');
    expect(page.threads.single.channelName, 'engineering');
    expect(page.threads.single.messages.single.author, 'Grace');
    expect(page.unseenCount, 3);
    expect(page.hasMore, isTrue);
  });
  test('supports legacy list payload without inventing unread counts', () {
    final page = ThreadsPage.fromJson({
      'data': [discussion('a')],
      'pagination': {'total_pages_count': 1},
    }, 1);
    expect(page.unseenCount, 0);
    expect(page.hasMore, isFalse);
  });
  test('honours the final pagination page', () {
    final page = ThreadsPage.fromJson({
      'data': [discussion('a')],
      'pagination': {'total_pages_count': '2'},
    }, 2);
    expect(page.hasMore, isFalse);
  });
  test('empty pages stop even when pagination claims more', () {
    final page = ThreadsPage.fromJson({
      'data': <dynamic>[],
      'pagination': {'total_pages_count': 9},
    }, 1);
    expect(page.hasMore, isFalse);
  });
  test('full pages without metadata permit another page', () {
    final page = ThreadsPage.fromJson({
      'data': List.generate(50, (i) => discussion('$i')),
    }, 1);
    expect(page.hasMore, isTrue);
  });
  test('negative unread counts cannot reach the UI', () {
    final page = ThreadsPage.fromJson({
      'data': {'threads': <dynamic>[], 'unseen_thread_count': -8},
    }, 1);
    expect(page.unseenCount, 0);
  });
  for (final bad in [
    null,
    'invalid',
    {'unexpected': <dynamic>[]},
  ]) {
    test('rejects malformed payload $bad instead of a false empty state', () {
      expect(
        () => ThreadsPage.fromJson({'data': bad}, 1),
        throwsFormatException,
      );
    });
  }
  test('rejects an empty discussion', () {
    expect(
      () => InboxThread.fromJson({'thread_messages': <dynamic>[]}),
      throwsFormatException,
    );
  });
  test('rejects missing channel identity', () {
    final json = discussion('a');
    (json['thread_messages'] as List).first.remove('channels_id');
    expect(() => InboxThread.fromJson(json), throwsFormatException);
  });
  test('uses the root thread id when the group has none', () {
    final json = discussion('a')..remove('thread_id');
    expect(InboxThread.fromJson(json).id, 'a');
  });
  test('returned discussion lists are immutable', () {
    final page = ThreadsPage.fromJson({
      'data': [discussion('a')],
    }, 1);
    expect(() => page.threads.clear(), throwsUnsupportedError);
    expect(() => page.threads.single.messages.clear(), throwsUnsupportedError);
  });
}
