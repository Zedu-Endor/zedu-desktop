import 'package:zedu/features/features.dart';

import '../../../../helpers/helpers.dart';

class MockDmRepository extends Mock implements DmRepository {}

void main() {
  late MockDmRepository dms;
  late InboxRepository repository;

  const alpha = Workspace(id: 'ws-alpha', name: 'Alpha', avatar: '');
  const beta = Workspace(id: 'ws-beta', name: 'Beta', avatar: '');
  const gamma = Workspace(id: 'ws-gamma', name: 'Gamma', avatar: '');

  DmConversation conversation({
    required String id,
    required String name,
    required DateTime at,
    int unread = 0,
    String type = 'dm',
  }) {
    return DmConversation(
      channelId: id,
      username: name,
      participantId: 'user-$id',
      channelType: type,
      previewMessage: 'preview $id',
      unreadCount: unread,
      lastReadAt: at,
      previewThreads: [
        DmPreviewThread(
          threadId: 'thread-$id',
          message: 'preview $id',
          userId: 'user-$id',
          username: name,
          createdAt: at,
        ),
      ],
    );
  }

  setUp(() {
    dms = MockDmRepository();
    repository = InboxRepository(dms, concurrency: 2);
  });

  void givenConversations(Workspace workspace, List<DmConversation> items) {
    when(() => dms.getConversations(orgId: workspace.id)).thenAnswer(
      (_) async => DmConversationsPage(
        conversations: items,
        currentPage: 1,
        totalPages: 1,
        totalItems: items.length,
      ),
    );
  }

  test('merges every workspace and orders newest first', () async {
    final now = DateTime.utc(2026, 11, 5, 12);
    givenConversations(alpha, [
      conversation(
        id: 'a1',
        name: 'Ada',
        at: now.subtract(const Duration(minutes: 30)),
      ),
    ]);
    givenConversations(beta, [conversation(id: 'b1', name: 'Grace', at: now)]);
    givenConversations(gamma, [
      conversation(
        id: 'g1',
        name: 'Alan',
        at: now.subtract(const Duration(hours: 2)),
      ),
    ]);

    final snapshot = await repository.load([alpha, beta, gamma]);

    expect(snapshot.items.map((item) => item.title), ['Grace', 'Ada', 'Alan']);
    expect(snapshot.failedWorkspaces, isEmpty);
  });

  test('labels each row with the workspace it came from', () async {
    final now = DateTime.utc(2026, 11, 5, 12);
    givenConversations(alpha, [conversation(id: 'a1', name: 'Ada', at: now)]);
    givenConversations(beta, const []);

    final snapshot = await repository.load([alpha, beta]);

    expect(snapshot.items.single.workspaceName, 'Alpha');
    expect(snapshot.items.single.workspaceId, 'ws-alpha');
  });

  test('one failing workspace does not empty the inbox', () async {
    final now = DateTime.utc(2026, 11, 5, 12);
    givenConversations(alpha, [conversation(id: 'a1', name: 'Ada', at: now)]);
    when(
      () => dms.getConversations(orgId: beta.id),
    ).thenThrow(Exception('boom'));
    givenConversations(gamma, [conversation(id: 'g1', name: 'Alan', at: now)]);

    final snapshot = await repository.load([alpha, beta, gamma]);

    expect(snapshot.items, hasLength(2));
    expect(snapshot.failedWorkspaces, ['Beta']);
    expect(snapshot.hasFailures, isTrue);
  });

  test('derives unread rows and the total across workspaces', () async {
    final now = DateTime.utc(2026, 11, 5, 12);
    givenConversations(alpha, [
      conversation(id: 'a1', name: 'Ada', at: now, unread: 3),
      conversation(id: 'a2', name: 'Read', at: now),
    ]);
    givenConversations(beta, [
      conversation(id: 'b1', name: 'Grace', at: now, unread: 2),
    ]);

    final snapshot = await repository.load([alpha, beta]);

    expect(snapshot.totalUnread, 5);
    expect(snapshot.unreadItems.map((item) => item.title), ['Ada', 'Grace']);
    expect(snapshot.items.where((item) => !item.isUnread).single.title, 'Read');
  });

  test('marks a group conversation as a group row', () async {
    final now = DateTime.utc(2026, 11, 5, 12);
    givenConversations(alpha, [
      conversation(id: 'a1', name: 'Team', at: now, type: 'group_dm'),
    ]);

    final snapshot = await repository.load([alpha]);

    expect(snapshot.items.single.kind, InboxItemKind.groupMessage);
  });

  test(
    'reads every workspace even when more than the concurrency limit',
    () async {
      final now = DateTime.utc(2026, 11, 5, 12);
      for (final workspace in [alpha, beta, gamma]) {
        givenConversations(workspace, [
          conversation(id: workspace.id, name: workspace.name, at: now),
        ]);
      }

      final snapshot = await repository.load([alpha, beta, gamma]);

      expect(snapshot.items, hasLength(3));
      for (final workspace in [alpha, beta, gamma]) {
        verify(() => dms.getConversations(orgId: workspace.id)).called(1);
      }
    },
  );
}
