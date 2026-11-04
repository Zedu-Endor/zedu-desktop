import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

TeamMember _member(String id, String name) => TeamMember(
  id: id,
  name: name,
  email: '$name@example.com',
  role: 'member',
  dateJoined: '2026-01-01',
  status: TeamMemberStatus.active,
);

Channel _channel(String name) => Channel(
  id: name,
  name: name,
  description: '$name channel',
  organisationId: 'org-1',
  ownerId: 'owner-1',
);

class _FakeUserProfileNotifier extends UserProfileNotifier {
  _FakeUserProfileNotifier(this.members);

  final List<TeamMember> members;

  @override
  UserProfileState build() => UserProfileState(teamMembers: members);
}

class _FakeChannelNotifier extends ChannelNotifier {
  _FakeChannelNotifier(this.channels);

  final List<Channel> channels;

  @override
  Future<List<Channel>> build() async => channels;
}

class _LoadingChannelNotifier extends ChannelNotifier {
  @override
  Future<List<Channel>> build() => Completer<List<Channel>>().future;
}

class _FakeWorkspaceNotifier extends WorkspaceNotifier {
  @override
  WorkspaceState build() => const WorkspaceState(
    selectedWorkspace: Workspace(id: 'org-1', name: 'Workspace', avatar: ''),
  );
}

class _FakeActiveChatNotifier extends ActiveChatNotifier {
  @override
  ActiveChatState build() => ActiveChatState.generalChannel;
}

void main() {
  Future<ProviderContainer> pumpView(
    WidgetTester tester, {
    List<TeamMember> members = const [],
    List<Channel> channels = const [],
    ChannelNotifier Function()? channelNotifier,
  }) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [
        userProfileNotifierProvider.overrideWith(
          () => _FakeUserProfileNotifier(members),
        ),
        channelProvider.overrideWith(
          channelNotifier ?? () => _FakeChannelNotifier(channels),
        ),
        workspaceProvider.overrideWith(_FakeWorkspaceNotifier.new),
        activeChatProvider.overrideWith(_FakeActiveChatNotifier.new),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: buildTestMaterialApp(const Scaffold(body: NewGroupChatView())),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  group('NewGroupChatView recipient suggestions', () {
    testWidgets('shows people and channels as soon as the page opens', (
      tester,
    ) async {
      await pumpView(
        tester,
        members: [_member('alice', 'Alice')],
        channels: [_channel('design')],
      );

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('#design'), findsOneWidget);
    });

    testWidgets('labels a person suggestion as an accessible button', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await pumpView(tester, members: [_member('alice', 'Alice')]);

        expect(
          find.bySemanticsLabel('Add Alice, Alice@example.com'),
          findsOneWidget,
        );
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('filters channels when typing a channel name', (tester) async {
      await pumpView(
        tester,
        members: [_member('alice', 'Alice')],
        channels: [_channel('design'), _channel('random')],
      );

      await tester.enterText(find.byType(TextField).first, '#design');
      await tester.pumpAndSettle();

      final suggestionList = find.byType(ListView);
      expect(
        find.descendant(of: suggestionList, matching: find.text('#design')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: suggestionList, matching: find.text('#random')),
        findsNothing,
      );
      expect(
        find.descendant(of: suggestionList, matching: find.text('Alice')),
        findsNothing,
      );
    });

    testWidgets('filters people by name or email with an @ prefix', (
      tester,
    ) async {
      await pumpView(
        tester,
        members: [_member('alice', 'Alice'), _member('bob', 'Bob')],
      );

      await tester.enterText(find.byType(TextField).first, '@bob@example.com');
      await tester.pumpAndSettle();

      final suggestions = find.byType(ListView);
      expect(
        find.descendant(of: suggestions, matching: find.text('Bob')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: suggestions, matching: find.text('Alice')),
        findsNothing,
      );
    });

    testWidgets('removes a selected person from the suggestions', (
      tester,
    ) async {
      await pumpView(tester, members: [_member('alice', 'Alice')]);

      await tester.tap(find.text('Alice'));
      await tester.pumpAndSettle();

      expect(find.byType(Chip), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.text('Alice'),
        ),
        findsNothing,
      );
    });

    testWidgets('ArrowDown and Enter select the highlighted suggestion', (
      tester,
    ) async {
      await pumpView(
        tester,
        members: [_member('alice', 'Alice'), _member('bob', 'Bob')],
      );
      await tester.tap(find.byType(TextField).first);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.byType(Chip), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
    });

    testWidgets('selecting a channel opens that channel', (tester) async {
      final container = await pumpView(tester, channels: [_channel('design')]);

      await tester.tap(find.text('#design'));
      await tester.pumpAndSettle();

      expect(container.read(activeChatProvider).type, ActiveChatType.channel);
      expect(container.read(activeChatProvider).id, 'design');
    });

    testWidgets('shows a useful no-match state', (tester) async {
      await pumpView(tester, members: [_member('alice', 'Alice')]);

      await tester.enterText(find.byType(TextField).first, 'nobody');
      await tester.pumpAndSettle();

      expect(
        find.text('No people or channels match “nobody”.'),
        findsOneWidget,
      );
    });

    testWidgets('shows an empty state when the workspace has no recipients', (
      tester,
    ) async {
      await pumpView(tester);

      expect(
        find.text('No people or channels are available in this workspace.'),
        findsOneWidget,
      );
    });

    testWidgets('shows a loading state while channels load', (tester) async {
      await pumpView(tester, channelNotifier: _LoadingChannelNotifier.new);

      expect(find.text('Loading people and channels…'), findsOneWidget);
    });
  });

  group('NewGroupChatView member names', () {
    const emptyNameMembers = [
      TeamMember(
        id: 'member-1',
        name: '',
        email: 'emptyname@zedu.test',
        role: 'Member',
        dateJoined: 'Jan 1, 2026',
        status: TeamMemberStatus.active,
      ),
      TeamMember(
        id: 'member-2',
        name: '   ',
        email: 'whitespace@zedu.test',
        role: 'Member',
        dateJoined: 'Jan 1, 2026',
        status: TeamMemberStatus.active,
      ),
      TeamMember(
        id: 'member-3',
        name: null,
        email: 'nullname@zedu.test',
        role: 'Member',
        dateJoined: 'Jan 1, 2026',
        status: TeamMemberStatus.active,
      ),
      TeamMember(
        id: 'member-4',
        name: 'Alice Cooper',
        email: 'alice@zedu.test',
        role: 'Admin',
        dateJoined: 'Jan 1, 2026',
        status: TeamMemberStatus.active,
      ),
    ];

    testWidgets(
      'renders contact list without crashing when members have empty or whitespace names',
      (tester) async {
        await pumpView(tester, members: emptyNameMembers);

        expect(find.text('emptyname'), findsOneWidget);
        expect(find.text('whitespace'), findsOneWidget);
        expect(find.text('nullname'), findsOneWidget);
        expect(find.text('Alice Cooper'), findsOneWidget);
      },
    );

    testWidgets(
      'renders selected member chip with safe initials and fallback label for empty name',
      (tester) async {
        await pumpView(tester, members: emptyNameMembers);

        await tester.tap(find.text('emptyname'));
        await tester.pumpAndSettle();

        expect(find.byType(Chip), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(Chip),
            matching: find.text('emptyname'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: find.byType(Chip), matching: find.text('EM')),
          findsOneWidget,
        );
      },
    );
  });
}
