import 'package:flutter/semantics.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import 'package:zedu/features/dms/presentation/components/composer/mention_suggestion_list.dart';
import '../../../helpers/helpers.dart';

DmParticipant _participant(String username) => DmParticipant(
  userId: 'user-$username',
  username: username,
  email: '$username@example.com',
);

class _FakeUserProfileNotifier extends UserProfileNotifier {
  @override
  UserProfileState build() => const UserProfileState(
    isLoading: false,
    teamMembers: [
      TeamMember(
        id: 'user-1',
        email: 'ada@example.com',
        role: 'admin',
        dateJoined: '2026-01-01',
        status: TeamMemberStatus.active,
        name: 'ada',
      ),
    ],
  );
}

void main() {
  group('MentionSuggestionList', () {
    testWidgets('labels each suggestion with the user it mentions', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        buildTestMaterialApp(
          Scaffold(
            body: MentionSuggestionList(
              suggestions: [_participant('ada'), _participant('grace')],
              query: 'a',
              colors: AppPalette.light,
              onSelect: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel(RegExp('Mention @ada')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Mention @grace')), findsOneWidget);

      handle.dispose();
    });

    testWidgets('exposes the suggestion rows as buttons', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        buildTestMaterialApp(
          Scaffold(
            body: MentionSuggestionList(
              suggestions: [_participant('ada')],
              query: 'a',
              colors: AppPalette.light,
              onSelect: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final node = tester.getSemantics(
        find.bySemanticsLabel(RegExp('Mention @ada')),
      );
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

      handle.dispose();
    });

    testWidgets('still inserts the mention when a row is picked', (
      tester,
    ) async {
      DmParticipant? picked;

      await tester.pumpWidget(
        buildTestMaterialApp(
          Scaffold(
            body: MentionSuggestionList(
              suggestions: [_participant('ada')],
              query: 'a',
              colors: AppPalette.light,
              onSelect: (p) => picked = p,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('ada'));
      await tester.pumpAndSettle();

      expect(picked, isNotNull);
      expect(picked!.username, 'ada');
    });
  });

  group('MessageComposer mention rows', () {
    testWidgets('labels the team member suggestions it shows', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileNotifierProvider.overrideWith(
              _FakeUserProfileNotifier.new,
            ),
          ],
          child: buildTestMaterialApp(
            Scaffold(
              body: MessageComposer(
                activeChat: ActiveChatState.generalChannel,
                onSend: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), '@');
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel(RegExp('Mention @ada')), findsOneWidget);

      handle.dispose();
    });
  });
}
