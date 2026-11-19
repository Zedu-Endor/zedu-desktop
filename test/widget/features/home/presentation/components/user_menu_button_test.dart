import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

void main() {
  testWidgets('shows a paused badge and clears it when resumed', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: Center(child: UserMenuButton())),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(UserMenuButton)),
    );

    expect(find.byKey(const ValueKey('user_menu_paused_badge')), findsNothing);

    container
        .read(notificationSettingsProvider.notifier)
        .setDndMode(const Duration(hours: 1));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('user_menu_paused_badge')),
      findsOneWidget,
    );
    expect(find.byTooltip('Notifications paused'), findsOneWidget);

    container.read(notificationSettingsProvider.notifier).clearDndMode();
    await tester.pump();

    expect(find.byKey(const ValueKey('user_menu_paused_badge')), findsNothing);
  });

  testWidgets('clears the paused badge when the pause expires', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: Center(child: UserMenuButton())),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(UserMenuButton)),
    );

    container
        .read(notificationSettingsProvider.notifier)
        .setDndMode(const Duration(minutes: 30));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('user_menu_paused_badge')),
      findsOneWidget,
    );

    await tester.pump(const Duration(minutes: 30, seconds: 1));
    await tester.pump();

    expect(find.byKey(const ValueKey('user_menu_paused_badge')), findsNothing);
  });
}
