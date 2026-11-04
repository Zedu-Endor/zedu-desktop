import '../../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockChannelRepository extends Mock implements ChannelRepository {}

void main() {
  late MockChannelRepository repository;

  setUp(() => repository = MockChannelRepository());

  Future<void> pumpList(WidgetTester tester, Result<List<ChannelMessage>> r) {
    when(
      () => repository.fetchChannelMessages('ch-1'),
    ).thenAnswer((_) async => r);
    return tester
        .pumpWidget(
          ProviderScope(
            overrides: [
              channelRepositoryProvider.overrideWithValue(repository),
            ],
            retry: (_, _) => null,
            child: buildTestMaterialApp(
              const Scaffold(
                body: ChannelMessageList(
                  channelId: 'ch-1',
                  empty: Text('Welcome to #general'),
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
}
