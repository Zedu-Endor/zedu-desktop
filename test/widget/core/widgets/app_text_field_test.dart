import 'package:zedu/core/core.dart';

import '../../../helpers/helpers.dart';

void main() {
  testWidgets('error borders keep the 6px radius and error colour', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppTextField(
            controller: controller,
            hint: 'Email',
            validator: (value) => 'Required',
          ),
        ),
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    final decoration = field.decoration!;
    final errorBorder = decoration.errorBorder! as OutlineInputBorder;
    final focusedErrorBorder =
        decoration.focusedErrorBorder! as OutlineInputBorder;

    expect(errorBorder.borderRadius, BorderRadius.circular(6));
    expect(errorBorder.borderSide.color, AppPalette.light.error);
    expect(focusedErrorBorder.borderRadius, BorderRadius.circular(6));
    expect(focusedErrorBorder.borderSide.color, AppPalette.light.error);
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

  group('AppTextField error borders', () {
    Matcher sixPxErrorBorder(Color color) => isA<OutlineInputBorder>()
        .having((b) => b.borderRadius, 'borderRadius', BorderRadius.circular(6))
        .having((b) => b.borderSide.color, 'colour', color);

    Future<InputDecorator> pumpAndValidate(WidgetTester tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        buildTestMaterialApp(
          Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: AppTextField(
                  controller: TextEditingController(),
                  hint: 'Email',
                  validator: (value) => 'Required',
                ),
              ),
            ),
          ),
        ),
      );
      formKey.currentState!.validate();
      await tester.pump();
      return tester.widget<InputDecorator>(find.byType(InputDecorator));
    }

    testWidgets('keeps the 6px radius and theme colour when validation fails', (
      tester,
    ) async {
      await pumpAndValidate(tester);
      final colors = tester.element(find.byType(InputDecorator)).colors;

      expect(find.text('Required'), findsOneWidget);
      final decorator = tester.widget<InputDecorator>(
        find.byType(InputDecorator),
      );
      expect(decorator.decoration.errorBorder, sixPxErrorBorder(colors.error));
      expect(
        decorator.decoration.focusedErrorBorder,
        sixPxErrorBorder(colors.error),
      );
    });

    testWidgets('declares error borders instead of falling back to defaults', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestMaterialApp(
          Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: AppTextField(
                controller: TextEditingController(),
                hint: 'Email',
              ),
            ),
          ),
        ),
      );

      final decoration = tester
          .widget<TextField>(find.byType(TextField))
          .decoration!;
      expect(decoration.errorBorder, isNotNull);
      expect(decoration.focusedErrorBorder, isNotNull);
    });
  });

  group('AppTextField obscureText sync (ziki-2764)', () {
    testWidgets(
      'syncs obscureText when isPassword changes from false to true',
      (tester) async {
        final controller = TextEditingController(text: 'secret123');
        addTearDown(controller.dispose);

        Widget buildWidget(bool isPassword) {
          return buildTestMaterialApp(
            Scaffold(
              body: AppTextField(
                controller: controller,
                hint: 'Field',
                isPassword: isPassword,
              ),
            ),
          );
        }

        await tester.pumpWidget(buildWidget(false));
        expect(
          tester.widget<TextField>(find.byType(TextField)).obscureText,
          isFalse,
        );

        // Change isPassword to true on existing widget
        await tester.pumpWidget(buildWidget(true));
        expect(
          tester.widget<TextField>(find.byType(TextField)).obscureText,
          isTrue,
        );
      },
    );

    testWidgets(
      'syncs obscureText when isPassword changes from true to false',
      (tester) async {
        final controller = TextEditingController(text: 'secret123');
        addTearDown(controller.dispose);

        Widget buildWidget(bool isPassword) {
          return buildTestMaterialApp(
            Scaffold(
              body: AppTextField(
                controller: controller,
                hint: 'Field',
                isPassword: isPassword,
              ),
            ),
          );
        }

        await tester.pumpWidget(buildWidget(true));
        expect(
          tester.widget<TextField>(find.byType(TextField)).obscureText,
          isTrue,
        );

        // Change isPassword to false on existing widget
        await tester.pumpWidget(buildWidget(false));
        expect(
          tester.widget<TextField>(find.byType(TextField)).obscureText,
          isFalse,
        );
      },
    );

    testWidgets(
      'preserves visibility toggle state when isPassword does not change',
      (tester) async {
        final controller = TextEditingController(text: 'secret123');
        addTearDown(controller.dispose);

        Widget buildWidget({required String hint}) {
          return buildTestMaterialApp(
            Scaffold(
              body: AppTextField(
                controller: controller,
                hint: hint,
                isPassword: true,
              ),
            ),
          );
        }

        await tester.pumpWidget(buildWidget(hint: 'Hint 1'));
        expect(
          tester.widget<TextField>(find.byType(TextField)).obscureText,
          isTrue,
        );

        // Tap toggle button to show password
        await tester.tap(find.byTooltip('Show password'));
        await tester.pump();
        expect(
          tester.widget<TextField>(find.byType(TextField)).obscureText,
          isFalse,
        );

        // Rebuild with same isPassword: true but different hint
        await tester.pumpWidget(buildWidget(hint: 'Hint 2'));
        expect(
          tester.widget<TextField>(find.byType(TextField)).obscureText,
          isFalse,
        );
      },
    );
  });
}
