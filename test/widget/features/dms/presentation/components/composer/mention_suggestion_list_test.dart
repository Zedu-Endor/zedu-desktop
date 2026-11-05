import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/dms/domain/dm_conversation.dart';
import 'package:zedu/features/dms/presentation/components/composer/composer.dart';

import '../../../../../../helpers/helpers.dart';

void main() {
  group('MentionSuggestionList', () {
    testWidgets('renders uppercase initial for ASCII usernames', (
      tester,
    ) async {
      final suggestions = [
        DmParticipant(
          userId: 'u1',
          username: 'alice',
          email: 'alice@example.com',
        ),
      ];

      await tester.pumpWidget(
        buildTestMaterialApp(
          Scaffold(
            body: MentionSuggestionList(
              suggestions: suggestions,
              query: 'al',
              colors: AppPalette.light,
              onSelect: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('A'), findsOneWidget);
      expect(find.text('alice'), findsOneWidget);
    });

    testWidgets(
      'preserves emojis and complex graphemes without splitting UTF-16 surrogate pairs',
      (tester) async {
        final suggestions = [
          DmParticipant(
            userId: 'u1',
            username: '😀 Ada',
            email: 'ada@example.com',
          ),
          DmParticipant(
            userId: 'u2',
            username: '🚀 Rocket',
            email: 'rocket@example.com',
          ),
          DmParticipant(
            userId: 'u3',
            username: '🇳🇬 Lagos',
            email: 'lagos@example.com',
          ),
        ];

        await tester.pumpWidget(
          buildTestMaterialApp(
            Scaffold(
              body: MentionSuggestionList(
                suggestions: suggestions,
                query: '',
                colors: AppPalette.light,
                onSelect: (_) {},
              ),
            ),
          ),
        );

        expect(find.text('😀'), findsOneWidget);
        expect(find.text('🚀'), findsOneWidget);
        expect(find.text('🇳🇬'), findsOneWidget);
      },
    );

    testWidgets(
      'trims leading whitespace and falls back to email initial when username is blank',
      (tester) async {
        final suggestions = [
          DmParticipant(
            userId: 'u1',
            username: '  bola',
            email: 'bola@example.com',
          ),
          DmParticipant(
            userId: 'u2',
            username: '   ',
            email: 'charlie@example.com',
          ),
        ];

        await tester.pumpWidget(
          buildTestMaterialApp(
            Scaffold(
              body: MentionSuggestionList(
                suggestions: suggestions,
                query: '',
                colors: AppPalette.light,
                onSelect: (_) {},
              ),
            ),
          ),
        );

        expect(find.text('B'), findsOneWidget);
        expect(find.text('C'), findsOneWidget);
      },
    );

    testWidgets('tapping a suggestion triggers onSelect callback', (
      tester,
    ) async {
      DmParticipant? selected;
      final participant = DmParticipant(
        userId: 'u1',
        username: 'bob',
        email: 'bob@example.com',
      );

      await tester.pumpWidget(
        buildTestMaterialApp(
          Scaffold(
            body: MentionSuggestionList(
              suggestions: [participant],
              query: 'b',
              colors: AppPalette.light,
              onSelect: (p) => selected = p,
            ),
          ),
        ),
      );

      await tester.tap(find.text('bob'));
      await tester.pump();

      expect(selected, isNotNull);
      expect(selected!.userId, 'u1');
    });
  });
}
