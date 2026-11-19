import 'dm_conversation.dart';

/// The conversations the DM sidebar shows when "Unread only" is on.
///
/// Order is left untouched so the caller keeps its sort (pinned first, then
/// the selected order).
List<DmConversation> unreadConversations(
  Iterable<DmConversation> conversations,
) => conversations.where((conversation) => conversation.isUnread).toList();
