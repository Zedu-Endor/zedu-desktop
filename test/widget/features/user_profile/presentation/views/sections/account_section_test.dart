import 'package:zedu/features/features.dart';

import '../../../../../../helpers/helpers.dart';

Future<void> _pump(WidgetTester tester, ProfileAccount account) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    buildTestMaterialApp(
      Scaffold(
        body: SingleChildScrollView(
          child: AccountSection(
            account: account,
            isSaving: false,
            onSave: (_) {},
            onDelete: () async {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  const account = ProfileAccount(
    name: 'Ada Lovelace',
    email: 'ada@zedu.test',
    timezone: 'Africa/Lagos',
  );

  testWidgets('shows the saved username as the handle', (tester) async {
    await _pump(tester, account.copyWith(username: 'CountessAda'));

    expect(find.text('@CountessAda'), findsOneWidget);
    expect(find.text('@adalovelace'), findsNothing);
  });

  testWidgets('trims the saved username', (tester) async {
    await _pump(tester, account.copyWith(username: '  ada_l '));

    expect(find.text('@ada_l'), findsOneWidget);
  });

  testWidgets('falls back to the name when there is no username', (
    tester,
  ) async {
    await _pump(tester, account);

    expect(find.text('@adalovelace'), findsOneWidget);
  });

  testWidgets('falls back to the name for a blank username', (tester) async {
    await _pump(tester, account.copyWith(username: '   '));

    expect(find.text('@adalovelace'), findsOneWidget);
  });
}
