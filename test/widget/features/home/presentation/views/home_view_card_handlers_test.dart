import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.authenticated);
}

class _FakeCreditsNotifier extends CreditsNotifier {
  @override
  CreditsState build() => const CreditsState();

  @override
  Future<void> load({String? orgId}) async {}
}

class _FakeWorkspaceNotifier extends WorkspaceNotifier {
  @override
  WorkspaceState build() => const WorkspaceState(
    selectedWorkspace: Workspace(
      id: 'org-1',
      name: 'Test Workspace',
      avatar: '',
    ),
  );
}

class _FakeChannelNotifier extends ChannelNotifier {
  @override
  Future<List<Channel>> build() async => [
    Channel(
      id: '1',
      name: 'general',
      description: 'General talk',
      organisationId: 'org-1',
      ownerId: 'u1',
      membersCount: 1,
    ),
    Channel(
      id: '2',
      name: 'random',
      description: 'Random talk',
      organisationId: 'org-1',
      ownerId: 'u1',
      membersCount: 3,
    ),
  ];
}

class _FakeUserProfileNotifier extends UserProfileNotifier {
  @override
  UserProfileState build() => const UserProfileState();

  @override
  Future<List<Map<String, dynamic>>> fetchRegisteredUsers() async => [];

  @override
  Future<String?> generateInviteLink() async => 'https://example.com/invite';

  @override
  Future<void> inviteMember({
    required String email,
    required String role,
    String? userId,
  }) async {}
}

class _FakeSecureStorageService extends Fake implements SecureStorageService {
  final _values = <String, String>{};

  @override
  Future<String?> readData(String key) async => _values[key];

  @override
  Future<void> writeData(String key, String value) async =>
      _values[key] = value;

  @override
  Future<void> deleteValue(String key) async => _values.remove(key);
}

Widget _buildHomeView() {
  return ProviderScope(
    overrides: [
      authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
      creditsNotifierProvider.overrideWith(_FakeCreditsNotifier.new),
      channelProvider.overrideWith(_FakeChannelNotifier.new),
      channelHistoryProvider.overrideWith(
        (ref, channelId) async => <ChannelMessage>[],
      ),
      workspaceProvider.overrideWith(_FakeWorkspaceNotifier.new),
      userProfileNotifierProvider.overrideWith(_FakeUserProfileNotifier.new),
      dmDraftStoreProvider.overrideWith(
        (ref) => DmDraftStore(
          _FakeSecureStorageService(),
          userId: 'user-1',
          orgId: 'org-1',
        ),
      ),
    ],
    child: const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomeView(),
    ),
  );
}

void main() {
  setUpAll(() {
    if (!locator.isRegistered<SecureStorageService>()) {
      locator.registerSingleton<SecureStorageService>(
        _FakeSecureStorageService(),
      );
    }
    if (!locator.isRegistered<AppConfig>()) {
      locator.registerSingleton<AppConfig>(
        const AppConfig(apiBaseUrl: 'http://test', usesMockData: false),
      );
    }
  });

  group('HomeView card tap handlers (Issue #1707)', () {
    testWidgets(
      'clicking View all channels in sidebar opens ChannelDirectoryView',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_buildHomeView());
        await tester.pumpAndSettle();

        // Initially in HomeChatArea with welcome text
        expect(find.byType(ChannelDirectoryView), findsNothing);
        expect(find.text('View all channels'), findsOneWidget);

        // Tap "View all channels"
        await tester.tap(find.text('View all channels'));
        await tester.pumpAndSettle();

        // ChannelDirectoryView should now be visible in the chat area
        expect(find.byType(ChannelDirectoryView), findsOneWidget);
        expect(find.text('Channel Directory'), findsOneWidget);

        // Clicking a channel in the directory navigates back to that channel chat
        final directoryChannel = find.descendant(
          of: find.byType(ChannelDirectoryView),
          matching: find.text('random'),
        );
        expect(directoryChannel, findsOneWidget);
        await tester.tap(directoryChannel);
        await tester.pumpAndSettle();

        expect(find.byType(ChannelDirectoryView), findsNothing);
        expect(find.text('# random'), findsOneWidget);
      },
    );

    testWidgets('clicking Invite teammates card opens InviteTeammatesModal', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildHomeView());
      await tester.pumpAndSettle();

      expect(find.byType(InviteTeammatesModal), findsNothing);

      // Find the card container (outside the button)
      final inviteCard = find.ancestor(
        of: find.text('Bring your team into Zedu'),
        matching: find.byType(Card),
      );
      expect(inviteCard, findsOneWidget);

      // Tap on the card title text (not the button)
      await tester.tap(find.text('Bring your team into Zedu'));
      await tester.pumpAndSettle();

      expect(find.byType(InviteTeammatesModal), findsOneWidget);
      expect(find.text('Add people to #general'), findsOneWidget);
    });
  });
}
