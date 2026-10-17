import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../helpers/helpers.dart';

class MemoryStorage extends SecureStorageService {
  final values = <String, String>{};
  bool fail = false;
  @override
  Future<String?> readData(String key) async {
    if (fail) throw Exception('read failed');
    return values[key];
  }

  @override
  Future<void> writeData(String key, String value) async {
    if (fail) throw Exception('write failed');
    values[key] = value;
  }
}

class DelayedStorage extends MemoryStorage {
  final pendingRead = Completer<void>();
  @override
  Future<String?> readData(String key) async {
    final value = values[key];
    await pendingRead.future;
    return value;
  }
}

final channel = Channel(
  id: 'channel-1',
  name: 'general',
  description: '',
  organisationId: 'workspace-1',
  ownerId: 'owner',
);
const scope = (userId: 'user-1', workspaceId: 'workspace-1');

ProviderContainer containerFor(MemoryStorage storage) => ProviderContainer(
  overrides: [
    channelScopeProvider.overrideWithValue(scope),
    starredChannelRepositoryProvider.overrideWithValue(
      StarredChannelRepositoryImpl(storage),
    ),
  ],
);

Future<void> load(ProviderContainer container) async {
  container.read(starredChannelProvider);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  test(
    'a channel without an ID reports an error instead of ignoring the click',
    () async {
      final container = containerFor(MemoryStorage());
      addTearDown(container.dispose);
      await load(container);
      await container
          .read(starredChannelProvider.notifier)
          .toggle(channel.copyWith(id: ''));
      expect(container.read(starredChannelProvider).error, contains('no ID'));
      expect(container.read(starredChannelProvider).ids, isEmpty);
    },
  );
  test(
    'a delayed load from the previous workspace cannot leak preferences',
    () async {
      final storage = DelayedStorage();
      final repository = StarredChannelRepositoryImpl(storage);
      await repository.save(scope.userId, scope.workspaceId, {channel.id});
      final container = containerFor(storage);
      addTearDown(container.dispose);
      container.read(starredChannelProvider);
      await Future<void>.delayed(Duration.zero);
      container.updateOverrides([
        channelScopeProvider.overrideWithValue((
          userId: 'other',
          workspaceId: 'other',
        )),
        starredChannelRepositoryProvider.overrideWithValue(repository),
      ]);
      container.read(starredChannelProvider);
      await Future<void>.delayed(Duration.zero);
      storage.pendingRead.complete();
      await Future<void>.delayed(Duration.zero);
      expect(container.read(starredChannelProvider).loaded, true);
      expect(container.read(starredChannelProvider).ids, isEmpty);
    },
  );

  test(
    'star, unstar, and restore using a fresh provider and repository',
    () async {
      final storage = MemoryStorage();
      final first = containerFor(storage);
      await load(first);
      await first.read(starredChannelProvider.notifier).toggle(channel);
      expect(first.read(starredChannelProvider).ids, {channel.id});
      first.dispose();
      final restarted = containerFor(storage);
      addTearDown(restarted.dispose);
      await load(restarted);
      expect(restarted.read(starredChannelProvider).ids, {channel.id});
      await restarted.read(starredChannelProvider.notifier).toggle(channel);
      expect(restarted.read(starredChannelProvider).ids, isEmpty);
      final result = await StarredChannelRepositoryImpl(
        storage,
      ).load(scope.userId, scope.workspaceId);
      expect((result as Success<Set<String>>).value, isEmpty);
    },
  );

  test(
    'storage isolates user and workspace with collision-safe keys',
    () async {
      final repository = StarredChannelRepositoryImpl(MemoryStorage());
      await repository.save('a.b', 'c', {'first'});
      await repository.save('a', 'b.c', {'second'});
      for (final ids in [
        ('a.b', 'c', {'first'}),
        ('a', 'b.c', {'second'}),
        ('other', 'c', <String>{}),
        ('a.b', 'other', <String>{}),
      ]) {
        final result = await repository.load(ids.$1, ids.$2);
        expect((result as Success<Set<String>>).value, ids.$3);
      }
    },
  );

  test(
    'failed save rolls back optimistic update; failed load can retry',
    () async {
      final storage = MemoryStorage();
      final container = containerFor(storage);
      addTearDown(container.dispose);
      await load(container);
      storage.fail = true;
      final saving = container
          .read(starredChannelProvider.notifier)
          .toggle(channel);
      expect(container.read(starredChannelProvider).ids, {channel.id});
      await saving;
      expect(container.read(starredChannelProvider).ids, isEmpty);
      expect(container.read(starredChannelProvider).error, isNotNull);
      container.read(starredChannelProvider.notifier).retry();
      await load(container);
      expect(container.read(starredChannelProvider).loaded, false);
      storage.fail = false;
      container.read(starredChannelProvider.notifier).retry();
      await load(container);
      expect(container.read(starredChannelProvider).loaded, true);
    },
  );

  test(
    'scope switches clear state and reject channels from another workspace',
    () async {
      final storage = MemoryStorage();
      final container = containerFor(storage);
      addTearDown(container.dispose);
      await load(container);
      await container.read(starredChannelProvider.notifier).toggle(channel);
      container.updateOverrides([
        channelScopeProvider.overrideWithValue((
          userId: 'user-2',
          workspaceId: 'workspace-2',
        )),
        starredChannelRepositoryProvider.overrideWithValue(
          StarredChannelRepositoryImpl(storage),
        ),
      ]);
      await load(container);
      expect(container.read(starredChannelProvider).ids, isEmpty);
      await container.read(starredChannelProvider.notifier).toggle(channel);
      expect(container.read(starredChannelProvider).ids, isEmpty);
    },
  );

  test('signed out sessions do not read or write preferences', () async {
    final storage = MemoryStorage();
    final container = ProviderContainer(
      overrides: [
        channelScopeProvider.overrideWithValue(null),
        starredChannelRepositoryProvider.overrideWithValue(
          StarredChannelRepositoryImpl(storage),
        ),
      ],
    );
    addTearDown(container.dispose);
    await load(container);
    await container.read(starredChannelProvider.notifier).toggle(channel);
    expect(container.read(starredChannelProvider).loaded, false);
    expect(storage.values, isEmpty);
  });
}
