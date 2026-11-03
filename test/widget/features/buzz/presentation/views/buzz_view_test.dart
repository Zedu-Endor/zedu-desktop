import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class _FakeRepository implements BuzzMeetingsRepository {
  _FakeRepository(this.result);

  final Result<String> result;
  int calls = 0;

  @override
  Future<Result<String>> createMeeting() async {
    calls++;
    return result;
  }
}

Future<void> _pump(WidgetTester tester, _FakeRepository repository) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        buzzMeetingsRepositoryProvider.overrideWithValue(repository),
        buzzOrgSlugProvider.overrideWithValue('acme'),
        buzzConfigProvider.overrideWithValue(
          const AppConfig(
            apiBaseUrl: 'https://api.zedu.chat/api/v1/',
            usesMockData: false,
          ),
        ),
      ],
      child: buildTestMaterialApp(const Scaffold(body: BuzzView())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the Buzz page', (tester) async {
    await _pump(tester, _FakeRepository(const Success('abc')));

    expect(
      find.text(
        'Seamless video calls and meetings for every learning community.',
      ),
      findsOneWidget,
    );
    expect(find.text('New meeting'), findsOneWidget);
    expect(find.text('Enter a code or link'), findsOneWidget);
  });

  testWidgets('Join is enabled once a code is typed', (tester) async {
    await _pump(tester, _FakeRepository(const Success('abc')));

    TextButton join() =>
        tester.widget<TextButton>(find.widgetWithText(TextButton, 'Join'));
    expect(join().onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'abc-defg-hij');
    await tester.pump();

    expect(join().onPressed, isNotNull);
  });

  testWidgets('a meeting for later shows its link to copy', (tester) async {
    final repository = _FakeRepository(const Success('abc-defg-hij'));
    await _pump(tester, repository);

    await tester.tap(find.text('New meeting'));
    await tester.pumpAndSettle();
    expect(find.text('Start an instant meeting'), findsOneWidget);
    await tester.tap(find.text('Create a meeting for later'));
    await tester.pumpAndSettle();

    expect(repository.calls, 1);
    expect(find.text("Here's the link to your meeting"), findsOneWidget);
    expect(
      find.text('https://zedu.chat/acme/buzz/abc-defg-hij'),
      findsOneWidget,
    );
    expect(find.byTooltip('Copy meeting link'), findsOneWidget);
  });
}
