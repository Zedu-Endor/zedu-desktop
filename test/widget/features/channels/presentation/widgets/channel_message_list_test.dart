import '../../../../../helpers/helpers.dart';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockChannelRepository extends Mock implements ChannelRepository {}

class FakeChatHistoryNotifier extends ChangeNotifier
    implements ChatHistoryNotifier {
  FakeChatHistoryNotifier(this.channelId);

  @override
  final String channelId;

  @override
  List<Map<String, dynamic>> messages = [];

  @override
  String get currentUserName => 'Test User';

  @override
  String? get currentUserAvatarUrl => null;

  @override
  String get currentUserId => 'me-1';

  String? retriedMessageId;

  @override
  Future<void> retryMessage(String messageId) async {
    retriedMessageId = messageId;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late MockChannelRepository repository;
  late FakeChatHistoryNotifier fakeChatHistory;

  setUp(() {
    repository = MockChannelRepository();
    fakeChatHistory = FakeChatHistoryNotifier('ch-1');
  });

  Future<void> pumpList(
    WidgetTester tester,
    Result<List<ChannelMessage>> r, {
    FakeChatHistoryNotifier? chatNotifier,
    int unreadCount = 0,
  }) {
    when(
      () => repository.fetchChannelMessages('ch-1'),
    ).thenAnswer((_) async => r);
    return tester
        .pumpWidget(
          ProviderScope(
            overrides: [
              channelRepositoryProvider.overrideWithValue(repository),
              chatHistoryProvider.overrideWith(
                (ref, channelId) => chatNotifier ?? fakeChatHistory,
              ),
            ],
            retry: (_, _) => null,
            child: buildTestMaterialApp(
              Scaffold(
                body: ChannelMessageList(
                  channelId: 'ch-1',
                  empty: const Text('Welcome to #general'),
                  unreadCount: unreadCount,
                ),
              ),
            ),
          ),
        )
        .then((_) => tester.pumpAndSettle());
  }

  testWidgets('shows the messages, newest at the bottom', (tester) async {
    await pumpList(
      tester,
      const Success([
        ChannelMessage(senderName: 'gold', text: 'newest'),
        ChannelMessage(senderName: 'Ada', text: 'oldest'),
      ]),
    );

    expect(find.text('Welcome to #general'), findsNothing);
    expect(
      tester.getTopLeft(find.text('oldest')).dy,
      lessThan(tester.getTopLeft(find.text('newest')).dy),
    );
  });

  testWidgets('opens a URL in a message when it is tapped', (tester) async {
    final opened = <Uri>[];
    final original = messageLinkLauncher;
    messageLinkLauncher = (uri) async {
      opened.add(uri);
      return true;
    };
    addTearDown(() => messageLinkLauncher = original);

    await pumpList(
      tester,
      const Success([
        ChannelMessage(senderName: 'Ada', text: 'https://example.com/channel'),
      ]),
    );
    await tester.tapAt(
      tester.getTopLeft(find.byType(SelectableText)) + const Offset(20, 8),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(opened, [Uri.parse('https://example.com/channel')]);
  });

  testWidgets('shows the welcome screen when empty', (tester) async {
    await pumpList(tester, const Success(<ChannelMessage>[]));

    expect(find.text('Welcome to #general'), findsOneWidget);
  });

  testWidgets('offers a retry when loading fails', (tester) async {
    await pumpList(tester, const Failure(ApiFailure(message: 'boom')));

    expect(find.text("Couldn't load messages. Retry"), findsOneWidget);
  });

  testWidgets(
    'renders placeholder initial for empty senderName without crashing',
    (tester) async {
      await pumpList(
        tester,
        const Success([ChannelMessage(senderName: '', text: 'empty sender')]),
      );

      expect(find.text('?'), findsOneWidget);
      expect(find.text('empty sender'), findsOneWidget);
    },
  );

  testWidgets(
    'shows sending indicator for optimistic pending channel message (#2571)',
    (tester) async {
      fakeChatHistory.messages = [
        {
          'id': 'temp-1',
          'content': 'Sending channel message',
          'channel_id': 'ch-1',
          'status': 'sending',
          'created_at': DateTime.now().toIso8601String(),
        },
      ];

      await pumpList(tester, const Success(<ChannelMessage>[]));

      expect(find.text('Sending channel message'), findsOneWidget);
      expect(find.text('Sending...'), findsOneWidget);
    },
  );

  testWidgets(
    'shows failed indicator and invokes retryMessage on tap (#2571)',
    (tester) async {
      fakeChatHistory.messages = [
        {
          'id': 'failed-msg-1',
          'content': 'Failed channel message',
          'channel_id': 'ch-1',
          'status': 'failed',
          'created_at': DateTime.now().toIso8601String(),
        },
      ];

      await pumpList(tester, const Success(<ChannelMessage>[]));

      expect(find.text('Failed channel message'), findsOneWidget);
      expect(find.text('Failed – Tap to retry'), findsOneWidget);

      await tester.tap(find.text('Failed – Tap to retry'));
      expect(fakeChatHistory.retriedMessageId, 'failed-msg-1');
    },
  );

  group('unread messages', () {
    // Newest first, as the server sends them: 'msg N' is the newest.
    Success<List<ChannelMessage>> messages(int n) => Success([
      for (var i = n; i >= 1; i--)
        ChannelMessage(senderName: 'Ada', text: 'msg $i'),
    ]);

    const divider = 'New messages';
    final jump = find.byKey(const ValueKey('jump-to-first-unread'));

    testWidgets('marks where the unread messages start', (tester) async {
      await pumpList(tester, messages(5), unreadCount: 3);

      // Unread: msg 5, msg 4, msg 3. The divider sits between msg 2 and msg 3.
      expect(find.text(divider), findsOneWidget);
      final dividerY = tester.getTopLeft(find.text(divider)).dy;
      expect(tester.getTopLeft(find.text('msg 2')).dy, lessThan(dividerY));
      expect(dividerY, lessThan(tester.getTopLeft(find.text('msg 3')).dy));
    });

    testWidgets('shows no divider when nothing was unread', (tester) async {
      await pumpList(tester, messages(5));

      expect(find.text(divider), findsNothing);
      expect(jump, findsNothing);
    });

    testWidgets('a few unread messages get the divider but no jump button', (
      tester,
    ) async {
      await pumpList(tester, messages(30), unreadCount: 3);

      expect(find.text(divider), findsOneWidget);
      expect(jump, findsNothing);
    });

    testWidgets('many unread messages offer a jump to the first one', (
      tester,
    ) async {
      await pumpList(tester, messages(40), unreadCount: 25);

      // The first unread message is msg 16, far above what is on screen.
      expect(jump, findsOneWidget);
      expect(find.text('Jump to first unread · 25 new'), findsOneWidget);
      final viewportHeight = tester.view.physicalSize.height;
      expect(
        find.text('msg 16'),
        findsNothing,
        reason: 'the first unread message is far above what is on screen',
      );

      await tester.tap(jump);
      await tester.pumpAndSettle();

      final y = tester.getTopLeft(find.text('msg 16')).dy;
      expect(y, inInclusiveRange(0, viewportHeight));
      expect(jump, findsNothing);
      expect(find.text(divider), findsOneWidget);
    });

    testWidgets('more unread than loaded puts the divider at the very top', (
      tester,
    ) async {
      await pumpList(tester, messages(5), unreadCount: 50);

      expect(find.text(divider), findsOneWidget);
      expect(jump, findsOneWidget);
      // Nothing is above the divider: it is above the oldest loaded message.
      final dividerY = tester.getTopLeft(find.text(divider)).dy;
      expect(dividerY, lessThan(tester.getTopLeft(find.text('msg 1')).dy));
    });
  });

  group('editing and deleting own messages (Ziki #2839)', () {
    const mine = ChannelMessage(
      senderName: 'Test User',
      text: 'my typo',
      threadId: 't-1',
      userId: 'me-1',
    );
    const theirs = ChannelMessage(
      senderName: 'Ada',
      text: 'not yours',
      threadId: 't-2',
      userId: 'u-2',
    );
    final actions = find.byKey(const ValueKey('channel-message-actions'));

    setUp(() {
      when(
        () => repository.editChannelMessage(
          channelId: any(named: 'channelId'),
          threadId: any(named: 'threadId'),
          content: any(named: 'content'),
        ),
      ).thenAnswer((_) async => const Success(null));
      when(
        () => repository.deleteChannelMessage(
          channelId: any(named: 'channelId'),
          threadId: any(named: 'threadId'),
        ),
      ).thenAnswer((_) async => const Success(null));
    });

    testWidgets('only your own messages get the actions menu', (tester) async {
      await pumpList(tester, const Success([mine, theirs]));

      expect(actions, findsOneWidget);
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text('my typo'),
            matching: find.byType(ChannelMessageTile),
          ),
          matching: actions,
        ),
        findsOneWidget,
      );
    });

    testWidgets('Edit saves the new text and reloads the channel', (
      tester,
    ) async {
      await pumpList(tester, const Success([mine]));

      await tester.tap(actions);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit message'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('channel-message-edit-field')),
        'fixed text',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      verify(
        () => repository.editChannelMessage(
          channelId: 'ch-1',
          threadId: 't-1',
          content: 'fixed text',
        ),
      ).called(1);
      verify(() => repository.fetchChannelMessages('ch-1')).called(2);
    });

    testWidgets('Delete asks first, then deletes and reloads', (tester) async {
      await pumpList(tester, const Success([mine]));

      await tester.tap(actions);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete message'));
      await tester.pumpAndSettle();
      expect(find.text('Delete message?'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      verify(
        () =>
            repository.deleteChannelMessage(channelId: 'ch-1', threadId: 't-1'),
      ).called(1);
      verify(() => repository.fetchChannelMessages('ch-1')).called(2);
    });

    testWidgets('cancelling the delete changes nothing', (tester) async {
      await pumpList(tester, const Success([mine]));

      await tester.tap(actions);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete message'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      verifyNever(
        () => repository.deleteChannelMessage(
          channelId: any(named: 'channelId'),
          threadId: any(named: 'threadId'),
        ),
      );
    });

    testWidgets('a failed edit says so', (tester) async {
      when(
        () => repository.editChannelMessage(
          channelId: any(named: 'channelId'),
          threadId: any(named: 'threadId'),
          content: any(named: 'content'),
        ),
      ).thenAnswer((_) async => const Failure(ApiFailure(message: 'offline')));
      await pumpList(tester, const Success([mine]));

      await tester.tap(actions);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit message'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('channel-message-edit-field')),
        'fixed text',
      );
      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(
        find.text("Couldn't edit the message. Please try again."),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  });
}
