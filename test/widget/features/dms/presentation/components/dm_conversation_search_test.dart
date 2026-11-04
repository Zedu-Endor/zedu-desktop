import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class MockChatHistory extends Mock implements ChatHistoryNotifier {}

class MockDraftStore extends Mock implements DmDraftStore {}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState();
}

final _today = DateTime.now();

final _messages = <Map<String, dynamic>>[
  {
    'id': 'm1',
    'content': '<p>The budget review is on Friday</p>',
    'created_at': DateTime(
      _today.year,
      _today.month,
      _today.day,
      16,
      5,
    ).toUtc().toIso8601String(),
    'mine': false,
  },
  {
    'id': 'm2',
    'content': 'Sounds good, see you then',
    'created_at': DateTime(2025, 11, 3, 9, 30).toUtc().toIso8601String(),
    'mine': true,
  },
];

Future<void> _openSearch(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final history = MockChatHistory();
  when(() => history.messages).thenReturn(_messages);
  when(() => history.isLoading).thenReturn(false);
  when(() => history.hasMore).thenReturn(false);
  when(() => history.currentUserName).thenReturn('Me');
  when(() => history.isMyMessage(any())).thenAnswer(
    (call) => (call.positionalArguments.first as Map)['mine'] == true,
  );
  final drafts = MockDraftStore();
  when(() => drafts.load(any())).thenAnswer((_) async => null);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
        chatHistoryProvider('chat-1').overrideWith((ref) => history),
        dmDraftStoreProvider.overrideWith((ref) => drafts),
      ],
      child: buildTestMaterialApp(
        Scaffold(
          body: DmChatArea(
            conversation: DmConversation(
              channelId: 'chat-1',
              username: 'Ada Obi',
              participantId: 'user-1',
              previewMessage: '',
              unreadCount: 0,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('More options'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Search in conversation'));
  await tester.pumpAndSettle();
}

Finder get _searchField => find.descendant(
  of: find.byType(AlertDialog),
  matching: find.byType(TextField),
);

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() {
    if (locator.isRegistered<AppConfig>()) {
      locator.unregister<AppConfig>();
    }
    locator.registerSingleton<AppConfig>(
      const AppConfig(apiBaseUrl: 'http://test', usesMockData: false),
    );
  });

  tearDown(() {
    if (locator.isRegistered<AppConfig>()) {
      locator.unregister<AppConfig>();
    }
  });

  group('Search in conversation', () {
    testWidgets('says nothing matched instead of showing a blank list', (
      tester,
    ) async {
      await _openSearch(tester);

      await tester.enterText(_searchField, 'zzzz');
      await tester.pump();

      expect(find.text('No messages match "zzzz"'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('shows the sender and time with each result', (tester) async {
      await _openSearch(tester);

      await tester.enterText(_searchField, 'budget');
      await tester.pump();

      expect(find.text('The budget review is on Friday'), findsOneWidget);
      expect(find.text('Ada Obi · 4:05 PM'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('labels my messages with my name and an earlier date', (
      tester,
    ) async {
      await _openSearch(tester);

      await tester.enterText(_searchField, 'see you');
      await tester.pump();

      expect(find.text('Sounds good, see you then'), findsOneWidget);
      expect(find.text('Me · Nov 3, 9:30 AM'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('matches the visible text, not the HTML tags', (tester) async {
      await _openSearch(tester);

      await tester.enterText(_searchField, '<p>');
      await tester.pump();

      expect(find.text('No messages match "<p>"'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('says the search covers only loaded messages', (tester) async {
      await _openSearch(tester);

      expect(
        find.text('Searches the messages loaded in this conversation.'),
        findsOneWidget,
      );
      expect(find.text('Enter a search term'), findsOneWidget);
      await _unmount(tester);
    });
  });
}
