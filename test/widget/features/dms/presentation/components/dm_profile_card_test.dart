import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

void main() {
  group('DmProfileCard', () {
    testWidgets('renders first letter capitalized for standard name', (
      tester,
    ) async {
      final conversation = DmConversation(
        channelId: 'dm-1',
        participantId: 'user-1',
        username: 'ada',
        previewMessage: 'Hello',
        unreadCount: 0,
      );

      await tester.pumpWidget(
        buildTestMaterialApp(DmProfileCard(conversation: conversation)),
      );

      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('renders complete emoji initial without surrogate split', (
      tester,
    ) async {
      final conversation = DmConversation(
        channelId: 'dm-2',
        participantId: 'user-2',
        username: '🚀 Rocket',
        previewMessage: 'Liftoff',
        unreadCount: 0,
      );

      await tester.pumpWidget(
        buildTestMaterialApp(DmProfileCard(conversation: conversation)),
      );

      expect(find.text('🚀'), findsOneWidget);
    });

    testWidgets('falls back to ? when name is whitespace only', (tester) async {
      final conversation = DmConversation(
        channelId: 'dm-3',
        participantId: 'user-3',
        username: '   ',
        previewMessage: 'Empty name',
        unreadCount: 0,
      );

      await tester.pumpWidget(
        buildTestMaterialApp(DmProfileCard(conversation: conversation)),
      );

      expect(find.text('?'), findsOneWidget);
    });
  });
}
