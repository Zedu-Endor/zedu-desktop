import 'package:flutter/gestures.dart';
import 'package:zedu/core/core.dart';
import '../../../helpers/helpers.dart';

Widget _buildAppWithToastButton({
  required AppToastType type,
  required String message,
}) {
  return buildTestMaterialApp(
    Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () =>
              AppToastService.show(context, type: type, message: message),
          child: const Text('Show toast'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('dismissing a toast twice does not throw', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      buildTestMaterialApp(
        Scaffold(
          body: Builder(
            builder: (ctx) {
              context = ctx;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    AppToastService.show(context, type: AppToastType.info, message: 'first');
    await tester.pump();

    // Two close taps start two dismiss animations. The second must not remove
    // an OverlayEntry the first already removed.
    final close = find.byIcon(Icons.close_rounded);
    final gesture = tester.widget<GestureDetector>(
      find.ancestor(of: close, matching: find.byType(GestureDetector)).first,
    );
    gesture.onTap!();
    gesture.onTap!();

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  group('AppToast', () {
    testWidgets(
      'shows message and title with close button tooltip and cursor',
      (tester) async {
        await tester.pumpWidget(
          _buildAppWithToastButton(
            type: AppToastType.info,
            message: 'Workspace settings saved',
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Show toast'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Info'), findsOneWidget);
        expect(find.text('Workspace settings saved'), findsOneWidget);

        final tooltipFinder = find.byTooltip('Dismiss notification');
        expect(tooltipFinder, findsOneWidget);

        final clickRegionFinder = find.ancestor(
          of: find.byIcon(Icons.close_rounded),
          matching: find.byWidgetPredicate(
            (w) => w is MouseRegion && w.cursor == SystemMouseCursors.click,
          ),
        );
        expect(clickRegionFinder, findsOneWidget);

        await tester.pump(const Duration(seconds: 4));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Workspace settings saved'), findsNothing);
      },
    );

    testWidgets('tapping close button dismisses toast immediately', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildAppWithToastButton(
          type: AppToastType.error,
          message: 'Failed to update channel',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show toast'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Failed to update channel'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Failed to update channel'), findsNothing);
    });

    testWidgets('hover pauses auto-dismiss and unhover resumes dismiss', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildAppWithToastButton(
          type: AppToastType.success,
          message: 'File downloaded successfully',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show toast'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('File downloaded successfully'), findsOneWidget);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(
        tester.getCenter(find.text('File downloaded successfully')),
      );
      await tester.pump();

      await tester.pump(const Duration(seconds: 5));
      expect(find.text('File downloaded successfully'), findsOneWidget);

      await gesture.moveTo(const Offset(0, 500));
      await tester.pump();

      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('File downloaded successfully'), findsNothing);
    });
  });
}
