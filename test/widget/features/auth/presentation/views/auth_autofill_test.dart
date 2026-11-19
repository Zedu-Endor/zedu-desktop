import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class _UnauthenticatedNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

Future<void> _verifyGroupedAutofill(
  WidgetTester tester,
  Widget view,
  List<List<String>> hints,
  List<String> values,
) async {
  tester.view.physicalSize = const Size(1440, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(_UnauthenticatedNotifier.new),
      ],
      child: buildTestMaterialApp(view),
    ),
  );
  await tester.pumpAndSettle();

  final fields = find.byType(EditableText);
  expect(fields, findsNWidgets(values.length));
  final states = tester.stateList<EditableTextState>(fields).toList();
  final group = AutofillGroup.maybeOf(states.first.context);
  expect(group, isNotNull);
  expect(group!.autofillClients.length, values.length);
  for (var i = 0; i < states.length; i++) {
    expect(AutofillGroup.maybeOf(states[i].context), same(group));
    expect(states[i].widget.autofillHints, hints[i]);
  }

  // Mimic one platform autofill event targeting every field in the group.
  // This tests Flutter's grouped dispatch, not a native password manager.
  await tester.showKeyboard(fields.first);
  final updates = <String, dynamic>{
    for (var i = 0; i < states.length; i++)
      states[i].autofillId: TextEditingValue(
        text: values[i],
        selection: TextSelection.collapsed(offset: values[i].length),
      ).toJSON(),
  };
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.textInput.name,
    SystemChannels.textInput.codec.encodeMethodCall(
      MethodCall('TextInputClient.updateEditingStateWithTag', [-1, updates]),
    ),
    (_) {},
  );
  await tester.pump();
  for (var i = 0; i < states.length; i++) {
    expect(states[i].widget.controller.text, values[i]);
  }
  expect(states.last.widget.obscureText, isTrue);
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('login autofills email and existing password together', (
    tester,
  ) async {
    await _verifyGroupedAutofill(
      tester,
      const LoginView(),
      const [
        [AutofillHints.username, AutofillHints.email],
        [AutofillHints.password],
      ],
      ['member@example.com', 'SavedPassword123!'],
    );
  });

  testWidgets('signup groups account details and requests a new password', (
    tester,
  ) async {
    await _verifyGroupedAutofill(
      tester,
      const SignUpView(),
      const [
        [AutofillHints.newUsername],
        [AutofillHints.email],
        [AutofillHints.newPassword],
      ],
      ['new-member', 'new@example.com', 'GeneratedPassword123!'],
    );
  });
}
