import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

class FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

class MockSecureStorageService extends Mock implements SecureStorageService {}

class FakeChannelNotifier extends ChannelNotifier {
  @override
  Future<List<Channel>> build() async => [
    Channel(
      id: 'id-general',
      name: 'general',
      description: 'Company-wide news',
      organisationId: 'org-1',
      ownerId: 'user-1',
    ),
    Channel(
      id: 'id-random',
      name: 'random',
      description: '',
      organisationId: 'org-1',
      ownerId: 'user-1',
    ),
  ];
}

Widget buildComposer({required bool isChannel}) {
  final storage = MockSecureStorageService();
  when(() => storage.readData(any())).thenAnswer((_) async => null);
  return ProviderScope(
    overrides: [
      authNotifierProvider.overrideWith(FakeAuthNotifier.new),
      dmDraftStoreProvider.overrideWith(
        (ref) => DmDraftStore(storage, userId: 'u', orgId: 'o'),
      ),
      channelProvider.overrideWith(FakeChannelNotifier.new),
    ],
    child: buildTestMaterialApp(
      Scaffold(
        body: DmMessageComposer(
          recipientName: 'qa',
          channelId: 'channel-1',
          isChannel: isChannel,
          participants: [
            DmParticipant(
              userId: 'user-1',
              username: 'ada_test',
              email: 'ada@example.com',
            ),
          ],
        ),
      ),
    ),
  );
}

TextEditingController composerController(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).controller;

Future<void> typeInComposer(WidgetTester tester, String text) async {
  await tester.tap(find.byType(TextField));
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
}

void main() {
  group('@channel (Ziki #4108)', () {
    testWidgets('a channel composer offers @channel for @cha and inserts it', (
      tester,
    ) async {
      await tester.pumpWidget(buildComposer(isChannel: true));
      await typeInComposer(tester, 'heads up @cha');

      expect(find.text('Notify everyone in this channel'), findsOneWidget);
      await tester.tap(find.text('channel'));
      await tester.pump();

      expect(composerController(tester).text, 'heads up @channel ');
    });

    testWidgets('a DM composer does not offer @channel', (tester) async {
      await tester.pumpWidget(buildComposer(isChannel: false));
      await typeInComposer(tester, '@cha');

      expect(find.text('Notify everyone in this channel'), findsNothing);
    });
  });

  group('#channel picker (Ziki #3778)', () {
    testWidgets('typing #ge lists matching channels and Enter picks one', (
      tester,
    ) async {
      await tester.pumpWidget(buildComposer(isChannel: true));
      await tester.pump();
      await typeInComposer(tester, 'see #ge');

      expect(find.text('Channels'), findsOneWidget);
      expect(find.text('general'), findsOneWidget);
      expect(find.text('random'), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(composerController(tester).text, 'see #general ');
      expect(find.text('Channels'), findsNothing);
    });

    testWidgets('Escape closes the channel list', (tester) async {
      await tester.pumpWidget(buildComposer(isChannel: true));
      await tester.pump();
      await typeInComposer(tester, '#');
      expect(find.text('random'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(find.text('Channels'), findsNothing);
    });
  });
}
