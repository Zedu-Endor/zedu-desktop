import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import 'package:zedu/features/dms/presentation/components/composer/composer.dart';

import '../../../../../../helpers/helpers.dart';

void main() {
  testWidgets(
    'suggestions announce the person and still select the right one',
    (tester) async {
      final semantics = tester.ensureSemantics();

      DmParticipant? selected;
      final suggestions = [
        DmParticipant(
          userId: 'ada-id',
          username: 'ada',
          email: 'ada@zedu.chat',
        ),
        DmParticipant(
          userId: 'bayo-id',
          username: 'bayo',
          email: 'bayo@zedu.chat',
        ),
      ];

      await tester.pumpWidget(
        buildTestMaterialApp(
          Scaffold(
            body: MentionSuggestionList(
              suggestions: suggestions,
              query: '',
              colors: AppPalette.light,
              onSelect: (person) => selected = person,
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel(RegExp('Mention @ada')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Mention @bayo')), findsOneWidget);

      await tester.tap(find.text('ada'));
      expect(selected?.userId, 'ada-id');
      semantics.dispose();
    },
  );
}
