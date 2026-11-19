import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

void main() {
  group('SidebarToggleButton', () {
    Future<ProviderContainer> pumpButton(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: buildTestMaterialApp(
            const Scaffold(body: SidebarToggleButton()),
          ),
        ),
      );
      return ProviderScope.containerOf(
        tester.element(find.byType(SidebarToggleButton)),
      );
    }

    testWidgets('hides the sidebar with one tap and shows it with the next', (
      tester,
    ) async {
      final container = await pumpButton(tester);

      expect(container.read(sidebarVisibilityProvider), isTrue);
      expect(find.byTooltip('Hide sidebar (⌘\\)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('sidebar-toggle')));
      await tester.pump();

      expect(container.read(sidebarVisibilityProvider), isFalse);
      expect(find.byTooltip('Show sidebar (⌘\\)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('sidebar-toggle')));
      await tester.pump();

      expect(container.read(sidebarVisibilityProvider), isTrue);
    });
  });
}
