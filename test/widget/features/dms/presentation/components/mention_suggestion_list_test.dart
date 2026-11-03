import 'package:zedu/core/core.dart';
import 'package:zedu/features/dms/presentation/components/composer/composer.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

void main() {
  group('MentionSuggestionList', () {
    testWidgets('renders capitalized initial for standard username', (
      tester,
    ) async {
      final participant = DmParticipant(
        userId: 'u-1',
        username: 'ada',
        email: 'ada@example.com',
      );

      await tester.pumpWidget(
        buildTestMaterialApp(
          Scaffold(
            body: MentionSuggestionList(
              suggestions: [participant],
              query: 'a',
              colors: AppPalette.light,
              onSelect: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('renders full emoji initial without splitting surrogate pairs', (
      tester,
    ) async {
      final participant = DmParticipant(
        userId: 'u-2',
        username: '🤖bot',
        email: 'bot@example.com',
      );

      await tester.pumpWidget(
        buildTestMaterialApp(
          Scaffold(
            body: MentionSuggestionList(
              suggestions: [participant],
              query: 'b',
              colors: AppPalette.light,
              onSelect: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('🤖'), findsOneWidget);
    });

    testWidgets('falls back to ? for whitespace-only username', (tester) async {
      final participant = DmParticipant(
        userId: 'u-3',
        username: '   ',
        email: 'blank@example.com',
      );

      await tester.pumpWidget(
        buildTestMaterialApp(
          Scaffold(
            body: MentionSuggestionList(
              suggestions: [participant],
              query: '',
              colors: AppPalette.light,
              onSelect: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('?'), findsOneWidget);
    });
  });
}
