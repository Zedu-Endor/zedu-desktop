import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../helpers/helpers.dart';

void main() {
  final conversation1 = DmConversation(
    channelId: 'dm-channel-1',
    username: 'Alice',
    participantId: 'user-alice',
    previewMessage: 'Hello there!',
    unreadCount: 0,
  );

  final conversation2 = DmConversation(
    channelId: 'dm-channel-2',
    username: 'Bob',
    participantId: 'user-bob',
    previewMessage: 'Are we meeting today?',
    unreadCount: 2,
  );

  testWidgets(
    'DmListTile renders unselected by default with transparent background',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: buildTestMaterialApp(
            Scaffold(body: DmListTile(conversation: conversation1)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final containerFinder = find.byType(Container).first;
      final containerWidget = tester.widget<Container>(containerFinder);
      final decoration = containerWidget.decoration as BoxDecoration;

      expect(decoration.color, equals(Colors.transparent));
    },
  );

  testWidgets(
    'DmListTile updates to selected background when tapped and persists after hover exit',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: buildTestMaterialApp(
            Scaffold(
              body: Column(
                children: [
                  DmListTile(conversation: conversation1),
                  DmListTile(conversation: conversation2),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on the first conversation to select it
      await tester.tap(find.text('Alice'));
      await tester.pumpAndSettle();

      // Check selectedDmProvider state
      expect(container.read(selectedDmProvider)?.channelId, equals('dm-channel-1'));

      // Check decoration color of Alice's tile
      final aliceContainerFinder = find.ancestor(
        of: find.text('Alice'),
        matching: find.byType(Container),
      ).first;
      final aliceBox = tester.widget<Container>(aliceContainerFinder).decoration as BoxDecoration;
      expect(aliceBox.color, isNot(equals(Colors.transparent)));

      // Simulate mouse hover and mouse exit
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(find.text('Alice')));
      await tester.pumpAndSettle();

      // Move away
      await gesture.moveTo(const Offset(500, 500));
      await tester.pumpAndSettle();

      // Selection color persists
      final aliceBoxAfterExit = tester.widget<Container>(aliceContainerFinder).decoration as BoxDecoration;
      expect(aliceBoxAfterExit.color, equals(aliceBox.color));

      // Now tap on Bob
      await tester.tap(find.text('Bob'));
      await tester.pumpAndSettle();

      expect(container.read(selectedDmProvider)?.channelId, equals('dm-channel-2'));

      // Alice is now unselected (transparent), Bob is selected
      final aliceBoxAfterSwitch = tester.widget<Container>(aliceContainerFinder).decoration as BoxDecoration;
      expect(aliceBoxAfterSwitch.color, equals(Colors.transparent));

      final bobContainerFinder = find.ancestor(
        of: find.text('Bob'),
        matching: find.byType(Container),
      ).first;
      final bobBox = tester.widget<Container>(bobContainerFinder).decoration as BoxDecoration;
      expect(bobBox.color, isNot(equals(Colors.transparent)));
    },
  );
}

