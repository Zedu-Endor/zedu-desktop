import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

void main() {
  group('ZeduCoinPanel', () {
    Future<void> pumpPanel(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        buildTestMaterialApp(
          const Scaffold(body: SingleChildScrollView(child: ZeduCoinPanel())),
        ),
      );
      await tester.pump();
    }

    testWidgets('shows the coin, status and fluctuation notice', (
      tester,
    ) async {
      await pumpPanel(tester);

      expect(find.text('Zedu Coin (ZDU)'), findsOneWidget);
      expect(find.text('Pre-launch'), findsOneWidget);
      expect(
        find.textContaining('blockchain payment token for in-app purchases'),
        findsOneWidget,
      );
      // The footer notice is always visible.
      expect(find.text('Prices are subject to fluctuation.'), findsOneWidget);
    });

    testWidgets('answers start collapsed and expand on tap', (tester) async {
      await pumpPanel(tester);

      const answer = 'At launch it will be how you';
      expect(find.textContaining(answer), findsNothing);

      await tester.tap(find.text('What is ZDU?'));
      await tester.pumpAndSettle();
      expect(find.textContaining(answer), findsOneWidget);

      await tester.tap(find.text('What is ZDU?'));
      await tester.pumpAndSettle();
      expect(find.textContaining(answer), findsNothing);
    });

    testWidgets('explains how people pay today', (tester) async {
      await pumpPanel(tester);

      await tester.tap(find.text('How do I pay today?'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Card payments for AI Credits continue as normal until ZDU launches.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('is read-only: no buy, wallet or price affordance', (
      tester,
    ) async {
      await pumpPanel(tester);

      expect(find.widgetWithText(FilledButton, 'Buy'), findsNothing);
      expect(find.textContaining('Buy'), findsNothing);
      expect(find.textContaining('\$'), findsNothing);
      expect(find.byIcon(Icons.account_balance_wallet), findsNothing);
    });
  });
}
