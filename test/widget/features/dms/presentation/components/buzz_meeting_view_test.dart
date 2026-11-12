import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

class FakeActiveCallNotifier extends ActiveCallNotifier {
  FakeActiveCallNotifier(super.ref, {required bool isFullPage})
    : _fakeState = ActiveCallState(
        status: CallStatus.active,
        remoteUserName: 'Ruby',
        isFullPage: isFullPage,
      );

  final ActiveCallState _fakeState;

  @override
  ActiveCallState get state => _fakeState;
}

Widget buildBuzzMeetingViewUnderTest({required bool isFullPage}) {
  return ProviderScope(
    overrides: [
      activeCallProvider.overrideWith(
        (ref) => FakeActiveCallNotifier(ref, isFullPage: isFullPage),
      ),
    ],
    // The compact view is a Positioned, so it needs a Stack ancestor.
    child: MaterialApp(
      home: Scaffold(body: Stack(children: const [BuzzMeetingView()])),
    ),
  );
}

void main() {
  group('BuzzMeetingView participant label', () {
    testWidgets('compact view shows "2 participants"', (tester) async {
      await tester.pumpWidget(buildBuzzMeetingViewUnderTest(isFullPage: false));
      await tester.pump();

      expect(find.text('2 participants'), findsOneWidget);
      expect(find.text('2 participant'), findsNothing);
    });

    testWidgets('full-page view shows "2 participants"', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(buildBuzzMeetingViewUnderTest(isFullPage: true));
      await tester.pump();

      expect(find.text('2 participants'), findsOneWidget);
      expect(find.text('2 participant'), findsNothing);
    });
  });
}
