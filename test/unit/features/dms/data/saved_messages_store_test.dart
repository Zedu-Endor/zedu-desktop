import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockSecureStorageService extends Mock implements SecureStorageService {}

SavedMessage saved(
  String messageId, {
  String channelId = 'ch-1',
  String content = 'hello',
  DateTime? savedAt,
}) => SavedMessage(
  messageId: messageId,
  channelId: channelId,
  conversationName: 'Ada Lovelace',
  senderName: 'Ada Lovelace',
  content: content,
  messageCreatedAt: DateTime(2026, 10, 17, 8),
  savedAt: savedAt ?? DateTime(2026, 11, 5, 9),
);

void main() {
  late MockSecureStorageService storage;
  late Map<String, String> values;

  setUp(() {
    storage = MockSecureStorageService();
    values = <String, String>{};

    when(() => storage.readData(any())).thenAnswer((invocation) async {
      final key = invocation.positionalArguments[0] as String;
      return values[key];
    });

    when(() => storage.writeData(any(), any())).thenAnswer((invocation) async {
      final key = invocation.positionalArguments[0] as String;
      final value = invocation.positionalArguments[1] as String;
      values[key] = value;
    });
  });

  test('starts empty and loads once', () async {
    final store = SavedMessagesStore(storage, userId: 'user-1');

    expect(store.items, isEmpty);
    expect(store.isLoaded, isFalse);

    await store.load();
    expect(store.isLoaded, isTrue);
    expect(store.items, isEmpty);
    expect(values, isEmpty);
  });

  test('saves an item and persists it for the signed-in user', () async {
    final store = SavedMessagesStore(storage, userId: 'user-1');
    await store.load();

    await store.save(saved('m1', content: 'keep me'));

    expect(store.isSaved('ch-1', 'm1'), isTrue);
    expect(store.items.single.content, 'keep me');

    final persisted =
        jsonDecode(values['saved_messages_user-1']!) as List<dynamic>;
    expect(persisted, hasLength(1));
    expect((persisted.single as Map<String, dynamic>)['messageId'], 'm1');
  });

  test('restores saved items on load, newest save first', () async {
    final earlier = saved('m1', savedAt: DateTime(2026, 11, 4, 9));
    final later = saved('m2', savedAt: DateTime(2026, 11, 5, 9));
    values['saved_messages_user-1'] = jsonEncode([
      earlier.toJson(),
      later.toJson(),
    ]);

    final store = SavedMessagesStore(storage, userId: 'user-1');
    await store.load();

    expect(store.items.map((item) => item.messageId), ['m2', 'm1']);
  });

  test('saving the same message twice keeps one entry', () async {
    final store = SavedMessagesStore(storage, userId: 'user-1');
    await store.load();

    await store.save(saved('m1', content: 'first'));
    await store.save(saved('m1', content: 'second'));

    expect(store.items, hasLength(1));
    expect(store.items.single.content, 'first');
  });

  test('toggle saves then removes', () async {
    final store = SavedMessagesStore(storage, userId: 'user-1');
    await store.load();
    final item = saved('m1');

    await store.toggle(item);
    expect(store.isSaved('ch-1', 'm1'), isTrue);

    await store.toggle(item);
    expect(store.isSaved('ch-1', 'm1'), isFalse);
    expect(
      jsonDecode(values['saved_messages_user-1']!) as List<dynamic>,
      isEmpty,
    );
  });

  test('remove only forgets the matching message', () async {
    final store = SavedMessagesStore(storage, userId: 'user-1');
    await store.load();

    await store.save(saved('m1'));
    await store.save(saved('m2'));
    await store.remove('ch-1:m1');

    expect(store.items.map((item) => item.messageId), ['m2']);
  });

  test('a corrupt stored list starts empty instead of throwing', () async {
    values['saved_messages_user-1'] = 'not json';

    final store = SavedMessagesStore(storage, userId: 'user-1');
    await store.load();

    expect(store.items, isEmpty);
    expect(store.isLoaded, isTrue);
  });

  test('a storage failure keeps the item for this session', () async {
    when(() => storage.writeData(any(), any())).thenThrow(Exception('disk'));
    final store = SavedMessagesStore(storage, userId: 'user-1');
    await store.load();

    await store.save(saved('m1'));

    expect(store.isSaved('ch-1', 'm1'), isTrue);
  });

  test('signed out does not read or write storage', () async {
    final store = SavedMessagesStore(storage, userId: '');
    await store.load();
    await store.save(saved('m1'));

    expect(store.isSaved('ch-1', 'm1'), isTrue);
    expect(values, isEmpty);
    verifyNever(() => storage.readData(any()));
    verifyNever(() => storage.writeData(any(), any()));
  });
}
