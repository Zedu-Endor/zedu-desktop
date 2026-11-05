import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class FakeIncomingCallNotifier extends ActiveCallNotifier {
  FakeIncomingCallNotifier(super.ref, {required String? remoteUserName})
    : _fakeState = ActiveCallState(
        status: CallStatus.incoming,
        remoteUserName: remoteUserName,
      );

  final ActiveCallState _fakeState;

  @override
  ActiveCallState get state => _fakeState;
}

Widget buildIncomingCallModalUnderTest({required String? remoteUserName}) {
  return ProviderScope(
    overrides: [
      activeCallProvider.overrideWith(
        (ref) => FakeIncomingCallNotifier(ref, remoteUserName: remoteUserName),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(body: Stack(children: const [IncomingCallModal()])),
    ),
  );
}

void main() {
  group('IncomingCallModal avatar initial', () {
    testWidgets('renders first letter uppercase for standard ASCII names', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildIncomingCallModalUnderTest(remoteUserName: 'alice'),
      );
      await tester.pump();

      expect(find.text('A'), findsOneWidget);
    });

    testWidgets(
      'safely renders emoji initial without corrupting surrogate pairs',
      (tester) async {
        await tester.pumpWidget(
          buildIncomingCallModalUnderTest(remoteUserName: '🚀 Rocket'),
        );
        await tester.pump();

        expect(find.text('🚀'), findsOneWidget);
      },
    );

    testWidgets(
      'renders fallback question mark when remoteUserName is null or empty',
      (tester) async {
        await tester.pumpWidget(
          buildIncomingCallModalUnderTest(remoteUserName: ''),
        );
        await tester.pump();

        expect(find.text('?'), findsOneWidget);
      },
    );
  });
}
