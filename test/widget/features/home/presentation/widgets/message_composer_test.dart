import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

class FakeUserProfileNotifier extends UserProfileNotifier {
  @override
  UserProfileState build() => const UserProfileState(isLoading: false);
}

Widget buildComposerUnderTest({
  ActiveChatState activeChat = ActiveChatState.generalChannel,
  ValueChanged<String>? onSend,
}) {
  return ProviderScope(
    overrides: [
      userProfileNotifierProvider.overrideWith(FakeUserProfileNotifier.new),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: MessageComposer(activeChat: activeChat, onSend: onSend ?? (_) {}),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MessageComposer', () {
    testWidgets('shows mic button when text field and attachments are empty', (
      tester,
    ) async {
      await tester.pumpWidget(buildComposerUnderTest());
      await tester.pump();

      expect(find.byIcon(Icons.mic_none), findsOneWidget);
      expect(find.byTooltip('Record voice note'), findsOneWidget);
      expect(find.byIcon(Icons.send), findsNothing);
    });

    testWidgets('switches to send button when text is typed', (tester) async {
      String? sentMessage;
      await tester.pumpWidget(
        buildComposerUnderTest(
          onSend: (msg) {
            sentMessage = msg;
          },
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.mic_none), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Hello world');
      await tester.pump();

      expect(find.byIcon(Icons.send), findsOneWidget);
      expect(find.byTooltip('Send message'), findsOneWidget);
      expect(find.byIcon(Icons.mic_none), findsNothing);

      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      expect(sentMessage, 'Hello world');
      expect(find.byIcon(Icons.mic_none), findsOneWidget);
    });

    testWidgets(
      'switches to send button when file is attached with empty text',
      (tester) async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('miguelruivo.flutter.plugins.filepicker'),
              (MethodCall methodCall) async {
                return [
                  {
                    'name': 'document.pdf',
                    'path': '/tmp/document.pdf',
                    'size': 1024,
                  },
                ];
              },
            );

        String? sentMessage;
        await tester.pumpWidget(
          buildComposerUnderTest(
            onSend: (msg) {
              sentMessage = msg;
            },
          ),
        );
        await tester.pump();

        expect(find.byIcon(Icons.mic_none), findsOneWidget);

        // Tap attach file button
        await tester.tap(find.byTooltip('Attach file'));
        await tester.pumpAndSettle();

        // Attachment chip should be displayed
        expect(find.text('document.pdf'), findsOneWidget);

        // Send button should be visible even though text field is empty
        expect(find.byIcon(Icons.send), findsOneWidget);
        expect(find.byTooltip('Send message'), findsOneWidget);
        expect(find.byIcon(Icons.mic_none), findsNothing);

        // Tap send button
        await tester.tap(find.byIcon(Icons.send));
        await tester.pumpAndSettle();

        // Sent message contains attachment marker and mic button returns
        expect(sentMessage, '[Attachment: document.pdf]');
        expect(find.byIcon(Icons.mic_none), findsOneWidget);
      },
    );
  });
}
