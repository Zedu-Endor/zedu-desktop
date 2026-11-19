import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

void main() {
  testWidgets(
    'showProfileConfirmDialog with destructive: true uses context.colors.error',
    (tester) async {
      BuildContext? dialogContext;
      await tester.pumpWidget(
        buildTestMaterialApp(
          Builder(
            builder: (context) {
              dialogContext = context;
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () => showProfileConfirmDialog(
                    context,
                    title: 'Delete account',
                    message: 'Are you sure?',
                    confirmLabel: 'Delete',
                    destructive: true,
                    onConfirm: () async {},
                  ),
                  child: const Text('Open Dialog'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Delete account'), findsOneWidget);
      expect(find.text('Are you sure?'), findsOneWidget);

      final button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton).last,
      );
      final backgroundColor = button.style?.backgroundColor?.resolve({});
      expect(backgroundColor, equals(dialogContext!.colors.error));
    },
  );

  testWidgets(
    'showProfileConfirmDialog with destructive: false does not use error color',
    (tester) async {
      BuildContext? dialogContext;
      await tester.pumpWidget(
        buildTestMaterialApp(
          Builder(
            builder: (context) {
              dialogContext = context;
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () => showProfileConfirmDialog(
                    context,
                    title: 'Confirm action',
                    message: 'Are you sure?',
                    confirmLabel: 'Confirm',
                    destructive: false,
                    onConfirm: () async {},
                  ),
                  child: const Text('Open Dialog'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      final button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton).last,
      );
      final backgroundColor = button.style?.backgroundColor?.resolve({});
      expect(backgroundColor, isNot(equals(dialogContext!.colors.error)));
    },
  );
}
