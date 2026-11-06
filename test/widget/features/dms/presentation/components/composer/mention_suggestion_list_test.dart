import 'package:zedu/core/core.dart';
import 'package:zedu/features/dms/presentation/components/composer/composer.dart';
import 'package:zedu/features/features.dart';

import '../../../../../../helpers/helpers.dart';

void main() {
  final ada = DmParticipant(
    userId: 'u1',
    username: 'ada',
    email: 'ada@example.com',
  );
  final grace = DmParticipant(userId: 'u2', username: 'grace', email: '');

  Future<List<DmParticipant>> pumpList(WidgetTester tester) async {
    final selected = <DmParticipant>[];
    await tester.pumpWidget(
      buildTestMaterialApp(
        Builder(
          builder: (context) => Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: MentionSuggestionList(
                suggestions: [ada, grace],
                query: '',
                colors: context.colors,
                onSelect: selected.add,
              ),
            ),
          ),
        ),
      ),
    );
    return selected;
  }

  testWidgets('each suggestion is announced as "Mention @username" '
      '(Ziki #590)', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpList(tester);

    for (final name in ['ada', 'grace']) {
      final row = find.bySemanticsLabel('Mention @$name');
      expect(row, findsOneWidget, reason: name);
      expect(
        tester.getSemantics(row),
        matchesSemantics(
          label: 'Mention @$name',
          isButton: true,
          hasTapAction: true,
        ),
      );
    }
    handle.dispose();
  });

  testWidgets('the semantics tap selects that person', (tester) async {
    final handle = tester.ensureSemantics();
    final selected = await pumpList(tester);

    tester.semantics.tap(find.semantics.byLabel('Mention @grace'));
    await tester.pump();

    expect(selected, [grace]);
    handle.dispose();
  });

  testWidgets('tapping a row still selects that person', (tester) async {
    final selected = await pumpList(tester);

    await tester.tap(find.text('ada'));
    await tester.pump();

    expect(selected, [ada]);
  });
}
