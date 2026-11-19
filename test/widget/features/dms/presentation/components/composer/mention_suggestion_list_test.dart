import 'package:zedu/core/core.dart';
import 'package:zedu/features/dms/dms.dart';
import 'package:zedu/features/dms/presentation/components/composer/mention_suggestion_list.dart';

import '../../../../../../helpers/helpers.dart';

const _longEmail = 'engineering-lead-notifications@my-organization.internal';
const _longName = 'engineering_lead_notifications_bot_account_name';

Future<void> pumpListAtWidth(
  WidgetTester tester,
  List<DmParticipant> people, {
  double width = 320,
}) async {
  await tester.pumpWidget(
    buildTestMaterialApp(
      Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: Builder(
              builder: (context) => MentionSuggestionList(
                suggestions: people,
                query: '',
                colors: context.colors,
                onSelect: (_) {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders fallback circle avatar with primary theme color', (
    tester,
  ) async {
    final participant = DmParticipant(
      userId: 'u-1',
      username: 'alice',
      email: 'alice@example.com',
      avatarUrl: null,
    );

    await tester.pumpWidget(
      buildTestMaterialApp(
        Scaffold(
          body: MentionSuggestionList(
            suggestions: [participant],
            query: 'ali',
            colors: AppPalette.light,
            onSelect: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('A'), findsOneWidget);
    final avatarWidget = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatarWidget.backgroundColor, equals(AppPalette.light.primary));
  });

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

  testWidgets('long username and email fit the row without overflowing', (
    tester,
  ) async {
    await pumpListAtWidth(tester, [
      DmParticipant(userId: 'u-3', username: _longName, email: _longEmail),
    ]);

    expect(tester.takeException(), isNull);
    for (final value in [_longName, _longEmail]) {
      final text = tester.widget<Text>(find.text(value));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    }
  });

  testWidgets('short names still render in full', (tester) async {
    await pumpListAtWidth(tester, [
      DmParticipant(userId: 'u-4', username: 'ada', email: 'ada@zedu.test'),
    ]);

    expect(tester.takeException(), isNull);
    expect(find.text('ada'), findsOneWidget);
    expect(find.text('ada@zedu.test'), findsOneWidget);
  });
}
