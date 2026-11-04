import "package:mocktail/mocktail.dart";
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class _Org extends Notifier<String> {
  @override
  String build() => 'org-a';

  void select(String orgId) => state = orgId;
}

final _orgProvider = NotifierProvider<_Org, String>(_Org.new);

/// Returns a full page at once, except the pages listed in [held], which wait
/// until the test completes them.
class _FakeDmRepository implements DmRepository {
  final held = <String, Completer<List<DmConversation>>>{};

  void hold(String orgId, int page) =>
      held['$orgId/$page'] = Completer<List<DmConversation>>();

  @override
  Future<List<DmConversation>> getConversations({
    required String orgId,
    int page = 1,
    bool recentDm = false,
    String? search,
  }) {
    final completer = held['$orgId/$page'];
    if (completer != null) return completer.future;
    return Future.value(_fullPage(orgId, page));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

DmConversation _conversation(String id) => DmConversation(
  channelId: id,
  username: id,
  participantId: id,
  previewMessage: '',
  unreadCount: 0,
);

List<DmConversation> _fullPage(String orgId, int page) => [
  for (var i = 0; i < DmRepository.pageSize; i++)
    _conversation('$orgId-p$page-$i'),
];

void main() {
  _mockGuardTests();
  _noFakeDmTests();

  late _FakeDmRepository repository;
  late ProviderContainer container;

  List<String> listedIds() => container
      .read(dmListProvider)
      .requireValue
      .map((c) => c.channelId)
      .toList();

  setUp(() async {
    repository = _FakeDmRepository();
    container = ProviderContainer(
      overrides: [
        dmRepositoryProvider.overrideWithValue(repository),
        currentOrgIdProvider.overrideWith((ref) => ref.watch(_orgProvider)),
      ],
    );
    addTearDown(container.dispose);
    container.listen(dmListProvider, (_, _) {});
    await container.read(dmListProvider.future);
  });

  test('loadMore appends the next page', () async {
    await container.read(dmListProvider.notifier).loadMore();

    expect(
      listedIds(),
      [
        ..._fullPage('org-a', 1),
        ..._fullPage('org-a', 2),
      ].map((c) => c.channelId),
    );
  });

  test(
    'a page from the previous workspace is dropped after a switch',
    () async {
      repository.hold('org-a', 2);
      final notifier = container.read(dmListProvider.notifier);
      final pending = notifier.loadMore();

      container.read(_orgProvider.notifier).select('org-b');
      await container.read(dmListProvider.future);

      // A short page, which would also mark the new list as having no more.
      repository.held['org-a/2']!.complete([_conversation('late-from-a')]);
      await pending;

      expect(listedIds(), _fullPage('org-b', 1).map((c) => c.channelId));
      expect(container.read(dmListProvider.notifier).hasMore, isTrue);
    },
  );

  test('a page from before a refresh is dropped', () async {
    repository.hold('org-a', 2);
    final notifier = container.read(dmListProvider.notifier);
    final pending = notifier.loadMore();

    await notifier.refresh();
    repository.held['org-a/2']!.complete([_conversation('late-page')]);
    await pending;

    expect(listedIds(), _fullPage('org-a', 1).map((c) => c.channelId));
    expect(notifier.hasMore, isTrue);
  });
}

/// Returns the same conversations for every page.
class _ListDmRepository implements DmRepository {
  _ListDmRepository(this.conversations);

  final List<DmConversation> conversations;

  @override
  Future<List<DmConversation>> getConversations({
    required String orgId,
    int page = 1,
    bool recentDm = false,
    String? search,
  }) async => conversations;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void _noFakeDmTests() {
  group('the list holds only what the API sent', () {
    ProviderContainer containerFor(List<DmConversation> conversations) {
      final container = ProviderContainer(
        overrides: [
          currentOrgIdProvider.overrideWithValue('org-1'),
          dmRepositoryProvider.overrideWithValue(
            _ListDmRepository(conversations),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('returns an empty list when the organisation has no DMs', () async {
      final container = containerFor(const []);

      final conversations = await container.read(dmListProvider.future);

      expect(conversations, isEmpty);
      expect(container.read(dmListProvider.notifier).hasMore, isFalse);
    });

    test('stays empty after a refresh that returns no DMs', () async {
      final container = containerFor(const []);
      await container.read(dmListProvider.future);

      await container.read(dmListProvider.notifier).refresh();

      expect(container.read(dmListProvider).value, isEmpty);
    });

    test('returns only the conversations the API sent', () async {
      final real = DmConversation(
        channelId: 'channel-1',
        username: 'Ada',
        participantId: 'user-1',
        previewMessage: 'Hi',
        unreadCount: 0,
      );
      final container = containerFor([real]);

      final conversations = await container.read(dmListProvider.future);

      expect(conversations, [real]);
    });
  });
}

class MockDmRepository extends Mock implements DmRepository {}

void _mockGuardTests() {
  late MockDmRepository mockRepo;

  setUp(() {
    mockRepo = MockDmRepository();
    if (locator.isRegistered<AppConfig>()) {
      locator.unregister<AppConfig>();
    }
  });

  tearDown(() {
    if (locator.isRegistered<AppConfig>()) {
      locator.unregister<AppConfig>();
    }
  });

  group('DmListNotifier mock guard (#2581)', () {
    test(
      'returns empty list in production mode when API returns empty list',
      () async {
        locator.registerSingleton<AppConfig>(
          const AppConfig(apiBaseUrl: 'http://test', usesMockData: false),
        );

        when(
          () => mockRepo.getConversations(orgId: 'test-org', page: 1),
        ).thenAnswer((_) async => <DmConversation>[]);

        final container = ProviderContainer(
          overrides: [
            currentOrgIdProvider.overrideWithValue('test-org'),
            dmRepositoryProvider.overrideWithValue(mockRepo),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(dmListProvider.future);

        expect(result, isEmpty);
        verify(
          () => mockRepo.getConversations(orgId: 'test-org', page: 1),
        ).called(1);
      },
    );

    test(
      'injects mock conversation when usesMockData is true and API returns empty list',
      () async {
        locator.registerSingleton<AppConfig>(
          const AppConfig(apiBaseUrl: 'http://test', usesMockData: true),
        );

        when(
          () => mockRepo.getConversations(orgId: 'test-org', page: 1),
        ).thenAnswer((_) async => <DmConversation>[]);

        final container = ProviderContainer(
          overrides: [
            currentOrgIdProvider.overrideWithValue('test-org'),
            dmRepositoryProvider.overrideWithValue(mockRepo),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(dmListProvider.future);

        expect(result, isNotEmpty);
        expect(result.first.channelId, 'mock-channel-id-123');
        expect(result.first.username, 'Test User');
        expect(
          result.first.previewMessage,
          'This is a test conversation. Tap to test the composer.',
        );
      },
    );

    test(
      'returns actual conversations regardless of usesMockData setting',
      () async {
        locator.registerSingleton<AppConfig>(
          const AppConfig(apiBaseUrl: 'http://test', usesMockData: false),
        );

        final realConversation = DmConversation(
          channelId: 'channel-real-456',
          username: 'Real User',
          participantId: 'user-456',
          previewMessage: 'Hello there!',
          unreadCount: 2,
        );

        when(
          () => mockRepo.getConversations(orgId: 'test-org', page: 1),
        ).thenAnswer((_) async => [realConversation]);

        final container = ProviderContainer(
          overrides: [
            currentOrgIdProvider.overrideWithValue('test-org'),
            dmRepositoryProvider.overrideWithValue(mockRepo),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(dmListProvider.future);

        expect(result.length, 1);
        expect(result.first.channelId, 'channel-real-456');
        expect(result.first.username, 'Real User');
      },
    );
  });
}
