import 'package:zedu/features/features.dart';

/// What an inbox row refers to. Mentions are not represented yet: the desktop
/// client has no mentions feed, which issue #2541 tracks separately.
enum InboxItemKind { directMessage, groupMessage }

/// One row in the cross-workspace inbox: a conversation, plus the workspace it
/// belongs to so the row can say where it came from and switch there on open.
class InboxItem {
  const InboxItem({
    required this.workspaceId,
    required this.workspaceName,
    required this.channelId,
    required this.title,
    required this.preview,
    required this.unreadCount,
    required this.lastActivityAt,
    required this.kind,
    required this.participantId,
    this.avatarUrl,
  });

  final String workspaceId;
  final String workspaceName;
  final String channelId;
  final String title;
  final String preview;
  final int unreadCount;
  final DateTime lastActivityAt;
  final InboxItemKind kind;

  /// The other participant, used to open a direct message.
  final String participantId;
  final String? avatarUrl;

  bool get isUnread => unreadCount > 0;

  /// Builds a row from a conversation already fetched for [workspace].
  factory InboxItem.fromConversation(
    DmConversation conversation,
    Workspace workspace,
  ) {
    return InboxItem(
      workspaceId: workspace.id,
      workspaceName: workspace.name,
      channelId: conversation.channelId,
      title: conversation.displayName,
      preview: conversation.previewMessage,
      unreadCount: conversation.unreadCount,
      lastActivityAt: conversation.lastActivityAt,
      kind: conversation.channelType == 'group_dm'
          ? InboxItemKind.groupMessage
          : InboxItemKind.directMessage,
      participantId: conversation.participantId,
      avatarUrl: conversation.effectiveAvatarUrl,
    );
  }
}

/// The inbox as a whole: the merged rows, and which workspaces could not be
/// read. One workspace failing degrades to a warning row rather than an empty
/// inbox, so a single bad response cannot hide every other workspace.
class InboxSnapshot {
  const InboxSnapshot({
    this.items = const [],
    this.failedWorkspaces = const [],
  });

  final List<InboxItem> items;
  final List<String> failedWorkspaces;

  List<InboxItem> get unreadItems =>
      items.where((item) => item.isUnread).toList(growable: false);

  int get totalUnread => items.fold(0, (sum, item) => sum + item.unreadCount);

  bool get hasFailures => failedWorkspaces.isNotEmpty;
}
