import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/dms/domain/dm_conversation.dart';

DmConversation conversationWith(String username) => DmConversation(
      channelId: 'channel-1',
      username: username,
      participantId: 'participant-1',
      previewMessage: 'Hey there',
      unreadCount: 0,
    );

void main() {
  group('DmConversation.dmHandle', () {
    test('prefixes a single-word username with @', () {
      expect(conversationWith('jemi').dmHandle, '@jemi');
    });

    test('joins first and last name with an underscore', () {
      expect(conversationWith('Jemi Oluchi').dmHandle, '@Jemi_Oluchi');
    });

    test('collapses runs of whitespace between words', () {
      expect(conversationWith('  Jemi   Oluchi  ').dmHandle, '@Jemi_Oluchi');
    });

    test('ignores surrounding whitespace on a single word', () {
      expect(conversationWith('  jemi  ').dmHandle, '@jemi');
    });

    test('uses first and last word when there are three or more', () {
      expect(conversationWith('Jemi Ada Oluchi').dmHandle, '@Jemi_Oluchi');
    });

    // The regression this getter exists for. `displayName` only falls back on an
    // empty username, so a whitespace-only one reaches the handle builder
    // intact. Before the fix the chat header returned '@user' while the profile
    // card returned a bare '@', labelling one person two different ways.
    test('falls back to @user for a whitespace-only username', () {
      expect(conversationWith('   ').dmHandle, '@user');
    });

    test('falls back to @user for a tab/newline-only username', () {
      expect(conversationWith('\t\n').dmHandle, '@user');
    });

    // An empty username becomes 'Unknown' via displayName, so the handle is
    // '@Unknown' rather than hitting the empty-parts fallback. Preserved
    // deliberately: this getter changes only the whitespace-only case, where
    // the two widgets previously disagreed.
    test('renders an empty username as @Unknown, matching displayName', () {
      expect(conversationWith('').dmHandle, '@Unknown');
    });

    test('displayName still reports Unknown for an empty username', () {
      expect(conversationWith('').displayName, 'Unknown');
      expect(conversationWith('   ').displayName, '   ');
    });
  });
}