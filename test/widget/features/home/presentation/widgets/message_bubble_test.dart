import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

void main() {
  group('MessageBubble anchor position logic', () {
    testWidgets(
      'computeMenuPosition computes RelativeRect from button & overlay',
      (tester) async {
        late BuildContext capturedButtonContext;
        late BuildContext capturedOverlayContext;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  Positioned(
                    left: 150,
                    top: 250,
                    width: 40,
                    height: 30,
                    child: Builder(
                      builder: (context) {
                        capturedButtonContext = context;
                        return const SizedBox();
                      },
                    ),
                  ),
                  Builder(
                    builder: (context) {
                      capturedOverlayContext = context;
                      return const SizedBox();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final buttonBox = capturedButtonContext.findRenderObject() as RenderBox;
        final overlayBox =
            capturedOverlayContext.findRenderObject() as RenderBox;

        final relativeRect = MessageBubble.computeMenuPosition(
          buttonBox,
          overlayBox,
        );

        expect(relativeRect.left, equals(150.0));
        expect(relativeRect.top, equals(250.0));
        expect(relativeRect.right, equals(overlayBox.size.width - 190.0));
        expect(relativeRect.bottom, equals(overlayBox.size.height - 280.0));
      },
    );
  });

  group('MessageBubble widget and reactions', () {
    testWidgets(
      'renders author, text, timestamp and responds to hover & reactions',
      (tester) async {
        String? lastReaction;

        await tester.pumpWidget(
          buildTestMaterialApp(
            Scaffold(
              body: Center(
                child: SizedBox(
                  width: 600,
                  child: MessageBubble(
                    author: 'Alice',
                    text: 'Hello from Zedu Desktop!',
                    timestamp: '10:30 AM',
                    onReactionAdded: (emoji) => lastReaction = emoji,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Alice'), findsOneWidget);
        expect(find.text('Hello from Zedu Desktop!'), findsOneWidget);
        expect(find.text('10:30 AM'), findsOneWidget);
        expect(
          find.byKey(const Key('message_add_reaction_button')),
          findsNothing,
        );

        // Hover over message to reveal reaction button
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        await gesture.moveTo(tester.getCenter(find.byType(MessageBubble)));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('message_add_reaction_button')),
          findsOneWidget,
        );

        // Tap reaction button to open menu
        await tester.tap(find.byKey(const Key('message_add_reaction_button')));
        await tester.pumpAndSettle();

        // Verify emoji menu items are presented
        expect(find.text('👍'), findsOneWidget);
        expect(find.text('❤️'), findsOneWidget);
        expect(find.text('😂'), findsOneWidget);
        expect(find.text('🎉'), findsOneWidget);
        expect(find.text('👎'), findsOneWidget);

        // Select emoji '👍'
        await tester.tap(find.text('👍'));
        await tester.pumpAndSettle();

        expect(lastReaction, equals('👍'));
        // Reaction count pill should appear
        expect(find.text('1'), findsOneWidget);

        // Tapping the reaction pill toggles/removes it
        await tester.tap(find.text('👍'));
        await tester.pumpAndSettle();
        expect(find.text('1'), findsNothing);
      },
    );

    testWidgets(
      'shows a trimmed initial and a placeholder for a blank author',
      (tester) async {
        Future<void> pump(String author) async {
          await tester.pumpWidget(
            buildTestMaterialApp(
              Scaffold(
                body: MessageBubble(
                  author: author,
                  text: 'hi',
                  timestamp: 'now',
                ),
              ),
            ),
          );
        }

        Finder avatarLetter(String letter) {
          return find.descendant(
            of: find.byType(CircleAvatar),
            matching: find.text(letter),
          );
        }

        await pump(' John');
        expect(avatarLetter('J'), findsOneWidget);

        await pump('');
        expect(avatarLetter('?'), findsOneWidget);

        await pump('   ');
        expect(avatarLetter('?'), findsOneWidget);
      },
    );
  });
}
