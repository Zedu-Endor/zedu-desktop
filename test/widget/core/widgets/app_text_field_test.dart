import 'package:zedu/core/core.dart';
import '../../../helpers/helpers.dart';

void main() {
  group('AppTextField password visibility toggle', () {
    testWidgets('labels the toggle with the action it performs', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        buildTestMaterialApp(
          Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: AppTextField(
                controller: TextEditingController(text: 'secret123'),
                hint: 'Password',
                isPassword: true,
              ),
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Show password'), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Hide password'), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

      semantics.dispose();
    });
  });

  group('AppTextField error borders', () {
    testWidgets(
      'defines errorBorder and focusedErrorBorder with 6px radius and error color',
      (tester) async {
        await tester.pumpWidget(
          buildTestMaterialApp(
            Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(24),
                child: AppTextField(
                  controller: TextEditingController(),
                  hint: 'Email',
                  validator: (val) => 'Invalid email',
                ),
              ),
            ),
          ),
        );

        final textField = tester.widget<TextField>(find.byType(TextField));
        final decoration = textField.decoration;
        expect(decoration, isNotNull);

        final errorBorder = decoration?.errorBorder as OutlineInputBorder?;
        expect(errorBorder, isNotNull);
        expect(errorBorder?.borderRadius, BorderRadius.circular(6));
        expect(errorBorder?.borderSide.color, AppPalette.light.error);

        final focusedErrorBorder =
            decoration?.focusedErrorBorder as OutlineInputBorder?;
        expect(focusedErrorBorder, isNotNull);
        expect(focusedErrorBorder?.borderRadius, BorderRadius.circular(6));
        expect(focusedErrorBorder?.borderSide.color, AppPalette.light.error);
      },
    );
  });
}
