import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

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

class _FakeChannelNotifier extends ChannelNotifier {
  @override
  Future<List<Channel>> build() async => [
    Channel(
      id: 'c1',
      name: 'general',
      description: 'General talk',
      organisationId: 'org-1',
      ownerId: 'u1',
      membersCount: 1,
    ),
    Channel(
      id: 'c2',
      name: 'random',
      description: 'Random talk',
      organisationId: 'org-1',
      ownerId: 'u1',
      membersCount: 2,
    ),
  ];
}

class _FakeUserProfileNotifier extends UserProfileNotifier {
  @override
  UserProfileState build() => const UserProfileState();
}

class _EmptyChannelRepository extends Mock implements ChannelRepository {
  @override
  Future<Result<List<ChannelMessage>>> fetchChannelMessages(String id) async =>
      const Success(<ChannelMessage>[]);
}

class _FakeSecureStorageService extends Fake implements SecureStorageService {
  @override
  Future<String?> readData(String key) async => null;

  @override
  Future<void> writeData(String key, String value) async {}

  @override
  Future<void> deleteValue(String key) async {}

  @override
  Future<String?> getAccessToken() async => null;
}

void main() {
  setUp(() {
    locator.registerSingleton<SecureStorageService>(
      _FakeSecureStorageService(),
    );
    locator.registerSingleton<AppConfig>(
      const AppConfig(apiBaseUrl: 'http://test/', usesMockData: false),
    );
    addTearDown(locator.reset);
  });

  Future<ProviderContainer> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
          creditsNotifierProvider.overrideWith(_FakeCreditsNotifier.new),
          channelProvider.overrideWith(_FakeChannelNotifier.new),
          userProfileNotifierProvider.overrideWith(
            _FakeUserProfileNotifier.new,
          ),
          channelRepositoryProvider.overrideWithValue(
            _EmptyChannelRepository(),
          ),
        ],
        child: buildTestMaterialApp(const HomeView()),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(HomeView)));
  }

  testWidgets('the top-bar button hides and shows the sidebar (Ziki #2848)', (
    tester,
  ) async {
    await pumpHome(tester);
    final sidebar = find.byKey(const ValueKey('resizable-sidebar'));
    expect(sidebar, findsOneWidget);
    final chatLeftBefore = tester.getTopLeft(find.byType(HomeChatArea)).dx;

    await tester.tap(find.byKey(const ValueKey('home-sidebar-toggle')));
    await tester.pumpAndSettle();

    expect(sidebar, findsNothing);
    expect(
      tester.getTopLeft(find.byType(HomeChatArea)).dx,
      lessThan(chatLeftBefore),
      reason: 'the chat area takes the freed width',
    );
    expect(find.byTooltip('Show sidebar (Ctrl+\\)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home-sidebar-toggle')));
    await tester.pumpAndSettle();

    expect(sidebar, findsOneWidget);
    expect(find.byTooltip('Hide sidebar (Ctrl+\\)'), findsOneWidget);
  });

  testWidgets('Ctrl+\\ toggles the sidebar from anywhere (Ziki #2848)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
          creditsNotifierProvider.overrideWith(_FakeCreditsNotifier.new),
          channelProvider.overrideWith(_FakeChannelNotifier.new),
          userProfileNotifierProvider.overrideWith(
            _FakeUserProfileNotifier.new,
          ),
          channelRepositoryProvider.overrideWithValue(
            _EmptyChannelRepository(),
          ),
        ],
        child: buildTestMaterialApp(
          const QuickSwitcherShortcut(
            child: Focus(autofocus: true, child: HomeView()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final sidebar = find.byKey(const ValueKey('resizable-sidebar'));
    expect(sidebar, findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.backslash);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(sidebar, findsNothing);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.backslash);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(sidebar, findsOneWidget);
  });

  testWidgets('the shortcuts list mentions the sidebar shortcut', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestMaterialApp(const KeyboardShortcutsDialog()),
    );
    expect(find.text('Show or hide the sidebar'), findsOneWidget);
  });
}
