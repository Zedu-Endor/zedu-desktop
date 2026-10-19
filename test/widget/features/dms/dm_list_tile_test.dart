import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../helpers/helpers.dart';

void main() {
  final sampleConversation = DmConversation(
    channelId: 'dm-1',
    username: 'Alice',
    participantId: 'p-1',
    previewMessage: 'Hello!',
    unreadCount: 0,
  );

  testWidgets('renders conversation display name and initial', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: buildTestMaterialApp(
          Scaffold(body: DmListTile(conversation: sampleConversation)),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('handles whitespace-only and empty names without crashing', (
    tester,
  ) async {
    final whitespaceConversation = DmConversation(
      channelId: 'dm-2',
      username: '   ',
      participantId: 'p-2',
      previewMessage: 'Hi',
      unreadCount: 0,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: buildTestMaterialApp(
          Scaffold(body: DmListTile(conversation: whitespaceConversation)),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('?'), findsOneWidget);
  });

  testWidgets('trims leading whitespace to extract the first letter', (
    tester,
  ) async {
    final leadingSpaceConversation = DmConversation(
      channelId: 'dm-3',
      username: '  Bob',
      participantId: 'p-3',
      previewMessage: 'Hey',
      unreadCount: 0,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: buildTestMaterialApp(
          Scaffold(body: DmListTile(conversation: leadingSpaceConversation)),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('B'), findsOneWidget);
  });
}
