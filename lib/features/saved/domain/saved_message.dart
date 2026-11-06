/// Whether the server holds this saved item as a whole thread or as one reply
/// inside a thread. The server names them `thread` and `message`, and the two
/// take different save endpoints, so the distinction has to survive the round
/// trip rather than being inferred in the UI.
enum SavedMessageKind {
  thread,
  reply;

  static SavedMessageKind fromWire(String? value) =>
      value == 'message' ? SavedMessageKind.reply : SavedMessageKind.thread;

  /// What the server expects in `type`.
  String get wire => this == SavedMessageKind.reply ? 'message' : 'thread';
}

/// Where a saved item lives, which is all that is needed to save it, set a
/// reminder on it, or open it again.
class SavedTarget {
  const SavedTarget({
    required this.channelId,
    required this.threadId,
    this.messageId,
  });

  final String channelId;

  /// The top-level message. For a reply this is its parent.
  final String threadId;

  /// Set only for a reply inside a thread.
  final String? messageId;

  SavedMessageKind get kind =>
      messageId == null ? SavedMessageKind.thread : SavedMessageKind.reply;

  /// Identifies a message in the UI, independently of whether the server has
  /// it saved yet, so the menu can show the right label before any refresh.
  String get key => '$channelId:${messageId ?? threadId}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedTarget &&
          channelId == other.channelId &&
          threadId == other.threadId &&
          messageId == other.messageId;

  @override
  int get hashCode => Object.hash(channelId, threadId, messageId);
}

/// One row of the Saved list, as the server reports it.
///
/// The reminder time arrives as `overdue_time`, which the server sets to the
/// stored reminder whether or not it has passed; `overdue` is the server's own
/// judgement that it has. Both are read from the server rather than compared
/// against the device clock, so a row cannot disagree with the notification
/// the server will send.
class SavedMessage {
  const SavedMessage({
    required this.id,
    required this.target,
    required this.kind,
    required this.authorName,
    required this.content,
    required this.savedAt,
    this.avatarUrl,
    this.conversationName,
    this.channelType,
    this.remindAt,
    this.overdue = false,
  });

  /// The saved item's own id. Removing uses this, not the thread id, which
  /// answers 404.
  final String id;

  final SavedTarget target;
  final SavedMessageKind kind;
  final String authorName;
  final String content;
  final DateTime savedAt;
  final String? avatarUrl;

  /// The channel name, or the other person for a direct message.
  final String? conversationName;

  /// `dm`, `groupDM`, `public` or `private`.
  final String? channelType;

  /// The reminder set on this item, if any.
  final DateTime? remindAt;

  /// The server's own judgement that the reminder has passed.
  final bool overdue;

  bool get hasReminder => remindAt != null;

  bool get isDirectMessage => channelType == 'dm' || channelType == 'groupDM';

  /// How the conversation reads in the list: a channel keeps its hash.
  String get conversationLabel {
    final name = conversationName;
    if (name == null || name.isEmpty) return 'Unknown conversation';
    return isDirectMessage ? name : '#$name';
  }

  /// A single line, so a long or multi-line message cannot stretch a row.
  String get preview {
    final collapsed = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    return collapsed.isEmpty ? 'No text' : collapsed;
  }

  static DateTime? _parseTime(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }

  static String _string(Object? value) => value?.toString() ?? '';

  factory SavedMessage.fromJson(Map<String, dynamic> json) {
    final threadId = _string(json['thread_id']);
    final rawMessageId = json['message_id'];
    final messageId = rawMessageId == null
        ? null
        : _string(rawMessageId).isEmpty
        ? null
        : _string(rawMessageId);

    return SavedMessage(
      id: _string(json['id']),
      target: SavedTarget(
        channelId: _string(json['channel_id']),
        threadId: threadId,
        messageId: messageId,
      ),
      kind: SavedMessageKind.fromWire(json['type'] as String?),
      authorName: _string(json['username']).isEmpty
          ? 'Unknown'
          : _string(json['username']),
      content: _string(json['content']),
      savedAt: _parseTime(json['saved_at']) ?? DateTime.now(),
      avatarUrl: _string(json['avatar_url']).isEmpty
          ? null
          : _string(json['avatar_url']),
      conversationName: _string(json['channel_name']).isEmpty
          ? null
          : _string(json['channel_name']),
      channelType: _string(json['channel_type']).isEmpty
          ? null
          : _string(json['channel_type']),
      remindAt: _parseTime(json['overdue_time']),
      overdue: json['overdue'] == true,
    );
  }
}
