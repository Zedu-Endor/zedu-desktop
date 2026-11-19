import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

class _Auth extends AuthNotifier {
  _Auth(this.status);

  final AuthStatus status;

  @override
  AuthState build() => AuthState(status: status);
}

class _Workspace extends WorkspaceNotifier {
  @override
  WorkspaceState build() => const WorkspaceState();

  @override
  Future<void> fetchWorkspaces() async {}
}

class _Channels extends ChannelNotifier {
  @override
  Future<List<Channel>> build() async => [
    _channel('c-general', 'general'),
    _channel('c-old', 'old-launch', archived: true),
    _channel('c-random', 'random'),
  ];
}

class _Dms extends DmListNotifier {
  @override
  Future<List<DmConversation>> build() async => [_gideon, _amara];
}

class _ActiveChat extends ActiveChatNotifier {
  _ActiveChat(this.initial);

  final ActiveChatState initial;

  @override
  ActiveChatState build() => initial;
}

Channel _channel(
  String id,
  String name, {
  bool archived = false,
  bool hasAccess = true,
  String organisationId = '',
}) => Channel(
  id: id,
  name: name,
  description: '',
  organisationId: organisationId,
  ownerId: 'owner',
  archived: archived,
  hasAccess: hasAccess,
);

DmPreviewThread _thread(String id, DateTime at) => DmPreviewThread(
  threadId: id,
  message: '',
  userId: 'u',
  username: 'u',
  createdAt: at,
);

final _gideon = DmConversation(
  channelId: 'c-gideon',
  username: 'Gideon',
  participantId: 'p-gideon',
  previewMessage: '',
  unreadCount: 0,
  previewThreads: [_thread('t-1', DateTime(2026, 11, 6, 12))],
);

final _amara = DmConversation(
  channelId: 'c-amara',
  username: 'Amara',
  participantId: 'p-amara',
  previewMessage: '',
  unreadCount: 0,
  previewThreads: [_thread('t-2', DateTime(2026, 11, 5, 12))],
);

const _inGeneral = ActiveChatState(
  type: ActiveChatType.channel,
  id: 'general',
  channelId: 'c-general',
);

const _inRandom = ActiveChatState(
  type: ActiveChatType.channel,
  id: 'random',
  channelId: 'c-random',
);

GoRouter _router() => GoRouter(
  initialLocation: '/settings',
  routes: [
    GoRoute(
      path: AppRouter.home,
      builder: (_, _) => const Scaffold(body: Text('home screen')),
    ),
    GoRoute(
      path: '/settings',
      builder: (_, _) => const Scaffold(body: TextField(autofocus: true)),
    ),
  ],
);

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  ActiveChatState chat = _inGeneral,
  HomeSidebarType sidebar = HomeSidebarType.home,
  DmConversation? selectedDm,
  AuthStatus status = AuthStatus.authenticated,
}) async {
  final router = _router();
  final container = ProviderContainer(
    overrides: [
      currentOrgIdProvider.overrideWithValue('org-test'),
      authNotifierProvider.overrideWith(() => _Auth(status)),
      workspaceProvider.overrideWith(_Workspace.new),
      channelProvider.overrideWith(_Channels.new),
      dmListProvider.overrideWith(_Dms.new),
      activeChatProvider.overrideWith(() => _ActiveChat(chat)),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => QuickSwitcherShortcut(
          router: router,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await container.read(channelProvider.future);
  await container.read(dmListProvider.future);
  container.read(homeSidebarProvider.notifier).setType(sidebar);
  if (selectedDm != null) {
    container.read(selectedDmProvider.notifier).select(selectedDm);
  }
  return container;
}

Future<void> _altArrow(WidgetTester tester, LogicalKeyboardKey arrow) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyEvent(arrow);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
  await tester.pumpAndSettle();
}

void main() {
  group('Alt+Down and Alt+Up', () {
    testWidgets('Alt+Down opens the next channel, even while typing', (
      tester,
    ) async {
      final container = await _pump(tester);

      await _altArrow(tester, LogicalKeyboardKey.arrowDown);

      final chat = container.read(activeChatProvider);
      expect(chat.type, ActiveChatType.channel);
      expect(chat.channelId, 'c-random');
      expect(find.text('home screen'), findsOneWidget);
    });

    testWidgets('Alt+Down skips archived channels', (tester) async {
      final container = await _pump(tester);

      await _altArrow(tester, LogicalKeyboardKey.arrowDown);

      expect(container.read(activeChatProvider).channelId, isNot('c-old'));
    });

    testWidgets('Alt+Down from the last channel opens the first DM', (
      tester,
    ) async {
      final container = await _pump(tester, chat: _inRandom);

      await _altArrow(tester, LogicalKeyboardKey.arrowDown);

      expect(container.read(homeSidebarProvider), HomeSidebarType.dms);
      expect(container.read(selectedDmProvider)?.channelId, 'c-gideon');
    });

    testWidgets('Alt+Down moves through the DMs in sidebar order', (
      tester,
    ) async {
      final container = await _pump(
        tester,
        sidebar: HomeSidebarType.dms,
        selectedDm: _gideon,
      );

      await _altArrow(tester, LogicalKeyboardKey.arrowDown);

      expect(container.read(selectedDmProvider)?.channelId, 'c-amara');
    });

    testWidgets('Alt+Down on the last conversation does nothing', (
      tester,
    ) async {
      final container = await _pump(
        tester,
        sidebar: HomeSidebarType.dms,
        selectedDm: _amara,
      );

      await _altArrow(tester, LogicalKeyboardKey.arrowDown);

      expect(container.read(selectedDmProvider)?.channelId, 'c-amara');
      expect(container.read(homeSidebarProvider), HomeSidebarType.dms);
    });

    testWidgets('Alt+Up on the first conversation does nothing', (
      tester,
    ) async {
      final container = await _pump(tester);

      await _altArrow(tester, LogicalKeyboardKey.arrowUp);

      expect(container.read(activeChatProvider), _inGeneral);
      expect(find.text('home screen'), findsNothing);
    });

    testWidgets('Alt+Up from the first DM opens the last channel', (
      tester,
    ) async {
      final container = await _pump(
        tester,
        sidebar: HomeSidebarType.dms,
        selectedDm: _gideon,
      );

      await _altArrow(tester, LogicalKeyboardKey.arrowUp);

      expect(container.read(homeSidebarProvider), HomeSidebarType.home);
      expect(container.read(activeChatProvider).channelId, 'c-random');
    });

    testWidgets('with nothing open, Alt+Down opens the first conversation', (
      tester,
    ) async {
      final container = await _pump(
        tester,
        chat: ActiveChatState.channelDirectory,
      );

      await _altArrow(tester, LogicalKeyboardKey.arrowDown);

      expect(container.read(activeChatProvider).channelId, 'c-general');
    });

    testWidgets('does nothing when signed out', (tester) async {
      final container = await _pump(tester, status: AuthStatus.unauthenticated);

      await _altArrow(tester, LogicalKeyboardKey.arrowDown);

      expect(container.read(activeChatProvider), _inGeneral);
    });
  });

  group('sidebarConversationOrder', () {
    test(
      'channels first, then DMs; leaves out channels of another workspace',
      () {
        final order = sidebarConversationOrder(
          channels: [
            _channel('a', 'alpha', organisationId: 'org-1'),
            _channel('b', 'beta', organisationId: 'org-2'),
            _channel('n', 'no-access', hasAccess: false),
          ],
          orgId: 'org-1',
          dms: [_amara, _gideon],
          actions: const DmConversationActions(),
          ownUserId: null,
        );

        expect(order.map((e) => e.label), ['alpha', 'Gideon', 'Amara']);
      },
    );

    test('hides deleted DMs and puts pinned DMs first', () {
      final order = sidebarConversationOrder(
        channels: const [],
        orgId: null,
        dms: [_gideon, _amara],
        actions: const DmConversationActions(pinnedIds: {'c-amara'}),
        ownUserId: null,
      );
      expect(order.map((e) => e.label), ['Amara', 'Gideon']);

      final withoutGideon = sidebarConversationOrder(
        channels: const [],
        orgId: null,
        dms: [_gideon, _amara],
        actions: const DmConversationActions(deletedIds: {'c-gideon'}),
        ownUserId: null,
      );
      expect(withoutGideon.map((e) => e.label), ['Amara']);
    });
  });

  group('adjacentConversation', () {
    final entries = [
      const QuickSwitcherEntry.channel('a', channelId: '1'),
      const QuickSwitcherEntry.channel('b', channelId: '2'),
      const QuickSwitcherEntry.channel('c', channelId: '3'),
    ];

    test('steps up and down and stops at both ends', () {
      expect(adjacentConversation(entries, 1, 1)?.label, 'c');
      expect(adjacentConversation(entries, 1, -1)?.label, 'a');
      expect(adjacentConversation(entries, 2, 1), isNull);
      expect(adjacentConversation(entries, 0, -1), isNull);
    });

    test('with none open, down gives the first and up gives nothing', () {
      expect(adjacentConversation(entries, null, 1)?.label, 'a');
      expect(adjacentConversation(entries, null, -1), isNull);
    });

    test('an empty list gives nothing', () {
      expect(adjacentConversation(const [], null, 1), isNull);
    });
  });
}
