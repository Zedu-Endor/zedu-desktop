import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../helpers/helpers.dart';

class MockSavedRepository extends Mock implements SavedRepository {}

SavedMessage item({
  required String id,
  String channelId = 'c1',
  String threadId = 't1',
  String? messageId,
  DateTime? savedAt,
  DateTime? remindAt,
  bool overdue = false,
}) => SavedMessage(
  id: id,
  target: SavedTarget(
    channelId: channelId,
    threadId: threadId,
    messageId: messageId,
  ),
  kind: messageId == null ? SavedMessageKind.thread : SavedMessageKind.reply,
  authorName: 'Ada',
  content: 'hello',
  savedAt: savedAt ?? DateTime.utc(2026, 11, 6, 8),
  remindAt: remindAt,
  overdue: overdue,
);

void main() {
  late MockSavedRepository repository;

  setUpAll(() {
    registerFallbackValue(
      const SavedTarget(channelId: 'c', threadId: 't'),
    );
  });

  setUp(() {
    repository = MockSavedRepository();
    when(
      () => repository.save(
        orgId: any(named: 'orgId'),
        target: any(named: 'target'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => repository.setReminder(
        orgId: any(named: 'orgId'),
        target: any(named: 'target'),
        remindAt: any(named: 'remindAt'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => repository.remove(
        orgId: any(named: 'orgId'),
        savedMessageId: any(named: 'savedMessageId'),
      ),
    ).thenAnswer((_) async {});
  });

  ProviderContainer containerWith(List<SavedMessage> items, {String org = 'org-1'}) {
    when(
      () => repository.list(orgId: any(named: 'orgId')),
    ).thenAnswer((_) async => items);

    final container = ProviderContainer(
      overrides: [
        savedRepositoryProvider.overrideWithValue(repository),
        currentOrgIdProvider.overrideWithValue(org),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('loads the saved list for the selected workspace', () async {
    final container = containerWith([item(id: 's1')]);

    await container.read(savedProvider.notifier).refresh();

    expect(container.read(savedProvider).items, hasLength(1));
    verify(() => repository.list(orgId: 'org-1')).called(1);
  });

  test('reading it does not fetch, so a message menu costs nothing', () async {
    final container = containerWith([item(id: 's1')]);

    // Simply observing the state, as every message menu does.
    expect(container.read(savedProvider).items, isEmpty);
    expect(container.read(savedKeysProvider), isEmpty);
    verifyNever(() => repository.list(orgId: any(named: 'orgId')));
  });

  test('with no workspace selected it asks the server for nothing', () async {
    final container = containerWith([item(id: 's1')], org: '');

    await container.read(savedProvider.notifier).refresh();

    expect(container.read(savedProvider).items, isEmpty);
    verifyNever(() => repository.list(orgId: any(named: 'orgId')));
  });

  test('a failed load is reported, not shown as an empty list', () async {
    when(
      () => repository.list(orgId: any(named: 'orgId')),
    ).thenThrow(Exception('offline'));

    final container = ProviderContainer(
      overrides: [
        savedRepositoryProvider.overrideWithValue(repository),
        currentOrgIdProvider.overrideWithValue('org-1'),
      ],
    );
    addTearDown(container.dispose);

    await container.read(savedProvider.notifier).refresh();

    final state = container.read(savedProvider);
    expect(state.error, isNotNull);
    expect(state.items, isEmpty);
  });

  test('overdue rows come first, then the most recently saved', () {
    final sorted = SavedNotifier.sortForDisplay([
      item(id: 'old', savedAt: DateTime.utc(2026, 11, 1)),
      item(id: 'due', savedAt: DateTime.utc(2026, 10, 1), overdue: true),
      item(id: 'new', savedAt: DateTime.utc(2026, 11, 5)),
    ]);

    expect(sorted.map((e) => e.id), ['due', 'new', 'old']);
  });

  test(
    'setting a reminder on an unsaved message saves it first, then reminds',
    () async {
      final container = containerWith([]);
      await container.read(savedProvider.notifier).refresh();

      const target = SavedTarget(channelId: 'c9', threadId: 't9');
      await container
          .read(savedProvider.notifier)
          .setReminder(target: target, remindAt: DateTime.utc(2026, 11, 6, 15));

      // On the server a reminder belongs to a saved message, so the order is
      // part of the contract, not an implementation detail.
      verifyInOrder([
        () => repository.save(orgId: 'org-1', target: target),
        () => repository.setReminder(
          orgId: 'org-1',
          target: target,
          remindAt: DateTime.utc(2026, 11, 6, 15),
        ),
      ]);
    },
  );

  test('a message already saved is not saved a second time', () async {
    const target = SavedTarget(channelId: 'c1', threadId: 't1');
    final container = containerWith([item(id: 's1')]);
    await container.read(savedProvider.notifier).refresh();

    await container
        .read(savedProvider.notifier)
        .setReminder(target: target, remindAt: DateTime.utc(2026, 11, 6, 15));

    verifyNever(
      () => repository.save(
        orgId: any(named: 'orgId'),
        target: any(named: 'target'),
      ),
    );
    verify(
      () => repository.setReminder(
        orgId: 'org-1',
        target: target,
        remindAt: DateTime.utc(2026, 11, 6, 15),
      ),
    ).called(1);
  });

  test('removing a message deletes by the saved id, not the thread id', () async {
    final container = containerWith([item(id: 'saved-55', threadId: 't1')]);
    await container.read(savedProvider.notifier).refresh();

    await container
        .read(savedProvider.notifier)
        .removeTarget(const SavedTarget(channelId: 'c1', threadId: 't1'));

    verify(
      () => repository.remove(orgId: 'org-1', savedMessageId: 'saved-55'),
    ).called(1);
  });

  test('removing a message the list does not know does nothing', () async {
    final container = containerWith([item(id: 'saved-55')]);
    await container.read(savedProvider.notifier).refresh();

    await container
        .read(savedProvider.notifier)
        .removeTarget(const SavedTarget(channelId: 'zz', threadId: 'zz'));

    verifyNever(
      () => repository.remove(
        orgId: any(named: 'orgId'),
        savedMessageId: any(named: 'savedMessageId'),
      ),
    );
  });

  test('a failed reminder reaches the caller instead of looking set', () async {
    final container = containerWith([]);
    await container.read(savedProvider.notifier).refresh();

    when(
      () => repository.setReminder(
        orgId: any(named: 'orgId'),
        target: any(named: 'target'),
        remindAt: any(named: 'remindAt'),
      ),
    ).thenThrow(Exception('rejected'));

    await expectLater(
      container.read(savedProvider.notifier).setReminder(
        target: const SavedTarget(channelId: 'c9', threadId: 't9'),
        remindAt: DateTime.utc(2026, 11, 6, 15),
      ),
      throwsException,
    );
  });

  test('savedKeys reports which messages are saved', () async {
    final container = containerWith([
      item(id: 's1', channelId: 'c1', threadId: 't1'),
    ]);
    await container.read(savedProvider.notifier).refresh();

    final keys = container.read(savedKeysProvider);
    expect(keys.contains('c1:t1'), isTrue);
    expect(keys.contains('c1:other'), isFalse);
  });
}
