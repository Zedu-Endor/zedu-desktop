import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

void main() {
  Future<void> pumpPanel(WidgetTester tester) async {
    await tester.pumpWidget(
      buildTestMaterialApp(
        Scaffold(
          body: GroupDetailsPanel(
            group: const GroupDM(id: 'group-1', name: 'Team', members: []),
            onClose: () {},
            onRename: (_) {},
            onLeave: () {},
          ),
        ),
      ),
    );
  }

  Finder buttonWith(IconData icon) =>
      find.ancestor(of: find.byIcon(icon), matching: find.byType(IconButton));

  String? tooltipOf(WidgetTester tester, IconData icon) =>
      tester.widget<IconButton>(buttonWith(icon)).tooltip;

  /// What a screen reader announces for the button.
  String semanticNameOf(WidgetTester tester, IconData icon) =>
      tester.getSemantics(buttonWith(icon)).getSemanticsData().tooltip;

  testWidgets('the close and edit buttons have tooltips', (tester) async {
    await pumpPanel(tester);

    expect(tooltipOf(tester, Icons.close), 'Close group details');
    expect(tooltipOf(tester, Icons.edit), 'Edit group name');
  });

  testWidgets('the save button has a tooltip while editing the name', (
    tester,
  ) async {
    await pumpPanel(tester);

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pump();

    expect(tooltipOf(tester, Icons.check), 'Save group name');
  });

  testWidgets('a screen reader gets a distinct name for each button', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpPanel(tester);

    expect(semanticNameOf(tester, Icons.close), 'Close group details');
    expect(semanticNameOf(tester, Icons.edit), 'Edit group name');

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pump();

    expect(semanticNameOf(tester, Icons.check), 'Save group name');
    semantics.dispose();
  });
}
