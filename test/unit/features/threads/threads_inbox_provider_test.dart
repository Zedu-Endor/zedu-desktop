import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class _Api extends Mock implements ApiBaseService {}

class _Repository extends ThreadsRepository {
  _Repository(this.handler) : super(_Api());
  final Future<ThreadsPage> Function(String, int) handler;
  @override
  Future<ThreadsPage> load(String orgId, {int page = 1}) =>
      handler(orgId, page);
}

final _user = User(
  id: 'u',
  firstName: 'Grace',
  lastName: 'Test',
  email: 'test@example.invalid',
  phone: '',
  username: 'tester',
  isVerified: true,
  isOnboarded: true,
  createdAt: DateTime(2026),
  currentOrg: 'org-a',
  currentOrganisationSlug: 'test',
  avatarUrl: '',
  defaultAvatarUrl: '',
);

class _Auth extends AuthNotifier {
  @override
  AuthState build() => AuthState(status: AuthStatus.authenticated, user: _user);
  void signOutForTest() {
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

ThreadsPage result(String id, {bool more = false}) => ThreadsPage(
  threads: [
    InboxThread(
      id: id,
      channelId: 'channel',
      channelName: 'engineering',
      messages: const [
        InboxThreadMessage(
          threadId: 'root',
          channelId: 'channel',
          author: 'Grace',
          content: 'Discussion',
        ),
      ],
    ),
  ],
  unseenCount: 2,
  hasMore: more,
);

ProviderContainer _make(_Repository repository) {
  final container = ProviderContainer(
    overrides: [
      authNotifierProvider.overrideWith(_Auth.new),
      currentOrgIdProvider.overrideWithValue('org-a'),
      threadsRepositoryProvider.overrideWithValue(repository),
    ],
  );
  final sub = container.listen(threadsInboxProvider, (_, _) {});
  addTearDown(() {
    sub.close();
    container.dispose();
  });
  return container;
}

void main() {
  test('loads the selected workspace and records unread total', () async {
    final calls = <(String, int)>[];
    final container = _make(
      _Repository((org, page) async {
        calls.add((org, page));
        return result('a');
      }),
    );
    await pumpEventQueue();
    expect(calls, [('org-a', 1)]);
    expect(container.read(threadsInboxProvider).threads.single.id, 'a');
    expect(container.read(threadsInboxProvider).unseenCount, 2);
  });
  test('workspace switch discards an older in-flight response', () async {
    final old = Completer<ThreadsPage>();
    final container = _make(
      _Repository(
        (org, _) => org == 'org-a' ? old.future : Future.value(result('new')),
      ),
    );
    await pumpEventQueue();
    container.updateOverrides([
      authNotifierProvider.overrideWith(_Auth.new),
      threadsRepositoryProvider.overrideWithValue(
        container.read(threadsRepositoryProvider),
      ),
      currentOrgIdProvider.overrideWithValue('org-b'),
    ]);
    await pumpEventQueue();
    old.complete(result('old'));
    await pumpEventQueue();
    expect(container.read(threadsInboxProvider).threads.single.id, 'new');
  });
  test(
    'logout clears discussions and ignores an outstanding response',
    () async {
      final request = Completer<ThreadsPage>();
      final container = _make(_Repository((_, _) => request.future));
      await pumpEventQueue();
      (container.read(authNotifierProvider.notifier) as _Auth).signOutForTest();
      await pumpEventQueue();
      request.complete(result('private'));
      await pumpEventQueue();
      expect(container.read(threadsInboxProvider).threads, isEmpty);
      expect(container.read(threadsInboxProvider).loading, isFalse);
    },
  );
  test('a failed next page keeps items and retries the same page', () async {
    final pages = <int>[];
    var fail = true;
    final container = _make(
      _Repository((_, page) async {
        pages.add(page);
        if (page == 2 && fail) {
          throw Exception('internal diagnostic');
        }
        return result(page == 1 ? 'first' : 'second', more: page == 1);
      }),
    );
    await pumpEventQueue();
    final actions = container.read(threadsInboxProvider.notifier);
    await actions.loadMore();
    expect(container.read(threadsInboxProvider).threads.single.id, 'first');
    expect(
      container.read(threadsInboxProvider).error,
      'Could not load threads. Please try again.',
    );
    fail = false;
    await actions.loadMore();
    expect(pages, [1, 2, 2]);
    expect(container.read(threadsInboxProvider).threads.map((t) => t.id), [
      'first',
      'second',
    ]);
  });
}
