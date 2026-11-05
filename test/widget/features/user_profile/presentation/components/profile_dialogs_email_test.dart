import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

void main() {
  const account = ProfileAccount(
    name: 'Ada Lovelace',
    email: 'ada@example.com',
    timezone: 'Africa/Lagos',
  );

  Finder emailField() => find.descendant(
    of: find.widgetWithText(AppTextField, 'Email Address'),
    matching: find.byType(TextFormField),
  );

  Future<void> pumpOpener(
    WidgetTester tester,
    VoidCallback Function(BuildContext) open,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      buildTestMaterialApp(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: open(context),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> openAccountDialog(
    WidgetTester tester,
    ValueChanged<ProfileAccount> onSave,
  ) => pumpOpener(
    tester,
    (context) =>
        () => showEditAccountDialog(context, account, onSave),
  );

  Future<void> openInviteDialog(
    WidgetTester tester,
    Future<void> Function({required String email, required String role})
    onInvite,
  ) => pumpOpener(
    tester,
    (context) =>
        () => showInviteMemberDialog(context, onInvite),
  );

  group('Edit account dialog email validation', () {
    testWidgets('rejects a malformed email such as a bare @', (tester) async {
      ProfileAccount? saved;
      await openAccountDialog(tester, (a) => saved = a);

      await tester.enterText(emailField(), '@');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email'), findsOneWidget);
      expect(saved, isNull);
    });

    testWidgets('reports a whitespace-only email as required', (tester) async {
      ProfileAccount? saved;
      await openAccountDialog(tester, (a) => saved = a);

      await tester.enterText(emailField(), '   ');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(find.text('Email is required'), findsOneWidget);
      expect(saved, isNull);
    });

    testWidgets('accepts a valid email with surrounding spaces', (
      tester,
    ) async {
      ProfileAccount? saved;
      await openAccountDialog(tester, (a) => saved = a);

      await tester.enterText(emailField(), '  grace@example.com  ');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email'), findsNothing);
      expect(find.text('Email is required'), findsNothing);
      expect(saved?.email, 'grace@example.com');
    });
  });

  group('Invite member dialog email validation', () {
    testWidgets('rejects an address with no domain', (tester) async {
      final invited = <String>[];
      await openInviteDialog(tester, ({required email, required role}) async {
        invited.add(email);
      });

      await tester.enterText(emailField(), 'name@');
      await tester.tap(find.text('Send Invite'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email'), findsOneWidget);
      expect(invited, isEmpty);
    });

    testWidgets('sends the invite for a valid email', (tester) async {
      final invited = <String>[];
      await openInviteDialog(tester, ({required email, required role}) async {
        invited.add(email);
      });

      await tester.enterText(emailField(), 'grace@example.com');
      await tester.tap(find.text('Send Invite'));
      await tester.pumpAndSettle();

      expect(invited, ['grace@example.com']);
    });
  });
}
