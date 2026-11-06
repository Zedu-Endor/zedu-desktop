import 'dart:math' as math;

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// The messages of a channel, newest at the bottom. Shows [empty] when the
/// channel has no messages yet.
///
/// [unreadCount] is how many messages were unread when the channel was opened
/// (opening it marks it read, so it is remembered here once). A divider marks
/// where they start, and when there are [manyUnread] or more a "Jump to first
/// unread" button scrolls to that point.
class ChannelMessageList extends ConsumerStatefulWidget {
  const ChannelMessageList({
    super.key,
    required this.channelId,
    required this.empty,
    this.unreadCount = 0,
  });

  final String channelId;
  final Widget empty;
  final int unreadCount;

  /// From this many unread messages on, the jump button is offered.
  static const manyUnread = 10;

  @override
  ConsumerState<ChannelMessageList> createState() => _ChannelMessageListState();
}

class _ChannelMessageListState extends ConsumerState<ChannelMessageList> {
  late final int _unreadAtOpen = widget.unreadCount;
  final _firstUnreadKey = GlobalKey();
  final _scroll = ScrollController();
  bool _jumped = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String get channelId => widget.channelId;

  /// Asks for the new text of [message] and saves it (Ziki #2839).
  Future<void> _editMessage(ChannelMessage message) async {
    final threadId = message.threadId;
    if (threadId == null) return;
    final edited = await showDialog<String>(
      context: context,
      builder: (_) => _EditChannelMessageDialog(initialText: message.text),
    );
    if (!mounted || edited == null) return;
    final text = edited.trim();
    if (text.isEmpty || text == message.text) return;
    final result = await ref
        .read(channelRepositoryProvider)
        .editChannelMessage(
          channelId: channelId,
          threadId: threadId,
          content: text,
        );
    if (!mounted) return;
    switch (result) {
      case Success():
        ref.invalidate(channelHistoryProvider(channelId));
      case Failure():
        AppToastService.show(
          context,
          type: AppToastType.error,
          message: "Couldn't edit the message. Please try again.",
        );
    }
  }

  /// Confirms, then deletes [message] for everyone (Ziki #2839).
  Future<void> _deleteMessage(ChannelMessage message) async {
    final threadId = message.threadId;
    if (threadId == null) return;
    final colors = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('It will be removed for everyone in the channel.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: colors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    final result = await ref
        .read(channelRepositoryProvider)
        .deleteChannelMessage(channelId: channelId, threadId: threadId);
    if (!mounted) return;
    switch (result) {
      case Success():
        ref.invalidate(channelHistoryProvider(channelId));
      case Failure():
        AppToastService.show(
          context,
          type: AppToastType.error,
          message: "Couldn't delete the message. Please try again.",
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatHistory = ref.watch(chatHistoryProvider(channelId));
    final pendingMessages = chatHistory.messages
        .where(
          (m) =>
              m['status'] != null &&
              (m['channel_id'] == channelId || m['is_channel'] == true),
        )
        .map(
          (m) => ChannelMessage(
            id: m['id']?.toString(),
            senderName: (m['sender_name'] as String?)?.isNotEmpty == true
                ? m['sender_name'] as String
                : chatHistory.currentUserName,
            avatarUrl: (m['avatar_url'] as String?)?.isNotEmpty == true
                ? m['avatar_url'] as String
                : chatHistory.currentUserAvatarUrl,
            text: m['content']?.toString() ?? '',
            createdAt: DateTime.tryParse(
              m['created_at']?.toString() ?? '',
            )?.toLocal(),
            status: m['status']?.toString(),
          ),
        )
        .toList();

    return ref
        .watch(channelHistoryProvider(channelId))
        .when(
          loading: () => pendingMessages.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _buildList(context, pendingMessages, 0),
          error: (_, _) => pendingMessages.isEmpty
              ? Center(
                  child: TextButton(
                    onPressed: () =>
                        ref.invalidate(channelHistoryProvider(channelId)),
                    child: const Text("Couldn't load messages. Retry"),
                  ),
                )
              : _buildList(context, pendingMessages, 0),
          data: (serverMessages) {
            final allMessages = [...pendingMessages, ...serverMessages];
            return allMessages.isEmpty
                ? widget.empty
                : _buildList(
                    context,
                    allMessages,
                    // Unread messages are the newest of the server's, so they
                    // sit right after the messages still being sent.
                    pendingMessages.length,
                    serverCount: serverMessages.length,
                  );
          },
        );
  }

  /// Where the unread run starts in [messages] (newest first), or null when
  /// there is nothing to mark. When more messages are unread than were loaded,
  /// the start is not on screen, so the oldest loaded one is used.
  int? _firstUnreadIndex(int offset, int serverCount) {
    if (_unreadAtOpen <= 0 || serverCount == 0) return null;
    final unread = _unreadAtOpen < serverCount ? _unreadAtOpen : serverCount;
    return offset + unread - 1;
  }

  /// Scrolls to the first unread message. It may be far from what is built,
  /// so this steps toward the older messages until it exists, then centres it.
  Future<void> _jump() async {
    setState(() => _jumped = true);
    for (var i = 0; i < 100 && _firstUnreadKey.currentContext == null; i++) {
      if (!_scroll.hasClients) return;
      final position = _scroll.position;
      if (position.pixels >= position.maxScrollExtent) break;
      _scroll.jumpTo(
        math.min(
          position.pixels + position.viewportDimension,
          position.maxScrollExtent,
        ),
      );
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
    final target = _firstUnreadKey.currentContext;
    if (target != null && target.mounted) {
      await Scrollable.ensureVisible(
        target,
        alignment: 0.5,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Widget _buildList(
    BuildContext context,
    List<ChannelMessage> messages,
    int pendingCount, {
    int serverCount = 0,
  }) {
    final firstUnread = _firstUnreadIndex(pendingCount, serverCount);
    // Read only when a message names its sender, so lists without sender ids
    // never touch the signed-in user.
    String? me;
    bool isMine(ChannelMessage message) {
      final sender = message.userId;
      if (sender == null || message.threadId == null) return false;
      if (message.status != null) return false;
      me ??= ref.read(chatHistoryProvider(channelId)).currentUserId;
      return me!.isNotEmpty && sender == me;
    }

    final offerJump =
        firstUnread != null &&
        !_jumped &&
        _unreadAtOpen >= ChannelMessageList.manyUnread;

    final list = ListView.builder(
      reverse: true,
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        // Only the sender's own, already sent messages can be changed.
        final own = isMine(message);
        final tile = ChannelMessageTile(
          message: message,
          onRetry: message.id != null
              ? () => ref
                    .read(chatHistoryProvider(channelId))
                    .retryMessage(message.id!)
              : null,
          onEdit: own ? () => _editMessage(message) : null,
          onDelete: own ? () => _deleteMessage(message) : null,
        );
        if (index != firstUnread) return tile;
        return Column(
          key: _firstUnreadKey,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [const _UnreadDivider(), tile],
        );
      },
    );

    // Always a Stack, so hiding the button never rebuilds the list underneath.
    return Stack(
      fit: StackFit.expand,
      children: [
        list,
        if (offerJump)
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: Center(
              child: FilledButton.tonalIcon(
                key: const ValueKey('jump-to-first-unread'),
                onPressed: _jump,
                icon: const Icon(Icons.arrow_upward, size: 16),
                label: Text('Jump to first unread · $_unreadAtOpen new'),
              ),
            ),
          ),
      ],
    );
  }
}

/// The line shown above the first message that was unread when the channel
/// was opened.
class _UnreadDivider extends StatelessWidget {
  const _UnreadDivider();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: colors.error)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'New messages',
              style: TextStyle(
                color: colors.error,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Divider(color: colors.error)),
        ],
      ),
    );
  }
}

class ChannelMessageTile extends StatelessWidget {
  const ChannelMessageTile({
    super.key,
    required this.message,
    this.onRetry,
    this.onEdit,
    this.onDelete,
  });

  final ChannelMessage message;
  final VoidCallback? onRetry;

  /// Set for the current user's own messages; shows Edit in the menu.
  final VoidCallback? onEdit;

  /// Set for the current user's own messages; shows Delete in the menu.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final avatarUrl = message.avatarUrl;
    final time = message.createdAt;
    final initial = avatarInitial(message.senderName);
    final status = message.status;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: colors.primary,
            foregroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            onForegroundImageError: avatarUrl != null
                ? ignoreAvatarError
                : null,
            child: Text(initial, style: TextStyle(color: colors.onPrimary)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: message.senderName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                          children: [
                            if (time != null)
                              TextSpan(
                                text:
                                    '  ${TimeOfDay.fromDateTime(time).format(context)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.normal,
                                  color: colors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (onEdit != null || onDelete != null)
                      _OwnMessageMenu(onEdit: onEdit, onDelete: onDelete),
                  ],
                ),
                const SizedBox(height: 4),
                ReportMessageMenu(
                  senderName: message.senderName,
                  messageText: message.text,
                  child: MessageLinkScope(
                    builder: (context, links) => SelectableText.rich(
                      links.span(
                        message.text,
                        TextStyle(fontSize: 15, color: colors.textPrimary),
                      ),
                    ),
                  ),
                ),
                if (status != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: status == 'failed'
                        ? GestureDetector(
                            onTap: onRetry,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 13,
                                  color: colors.error,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Failed – Tap to retry',
                                  style: TextStyle(
                                    color: colors.error,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Text(
                            status == 'sending' ? 'Sending...' : '',
                            style: TextStyle(
                              color: colors.textHint,
                              fontSize: 11,
                            ),
                          ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Edit and Delete for the current user's own channel message.
class _OwnMessageMenu extends StatelessWidget {
  const _OwnMessageMenu({this.onEdit, this.onDelete});

  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: 28,
      height: 20,
      child: PopupMenuButton<String>(
        key: const ValueKey('channel-message-actions'),
        tooltip: 'Message actions',
        padding: EdgeInsets.zero,
        iconSize: 18,
        icon: Icon(Icons.more_horiz, color: colors.textSecondary),
        onSelected: (value) {
          if (value == 'edit') onEdit?.call();
          if (value == 'delete') onDelete?.call();
        },
        itemBuilder: (_) => [
          if (onEdit != null)
            const PopupMenuItem(value: 'edit', child: Text('Edit message')),
          if (onDelete != null)
            PopupMenuItem(
              value: 'delete',
              child: Text(
                'Delete message',
                style: TextStyle(color: colors.error),
              ),
            ),
        ],
      ),
    );
  }
}

/// Edits a channel message's text; pops the new text, or null on Cancel.
class _EditChannelMessageDialog extends StatefulWidget {
  const _EditChannelMessageDialog({required this.initialText});

  final String initialText;

  @override
  State<_EditChannelMessageDialog> createState() =>
      _EditChannelMessageDialogState();
}

class _EditChannelMessageDialogState extends State<_EditChannelMessageDialog> {
  late final _controller = TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit message'),
      content: SizedBox(
        width: 420,
        child: TextField(
          key: const ValueKey('channel-message-edit-field'),
          controller: _controller,
          autofocus: true,
          minLines: 1,
          maxLines: 6,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) => FilledButton(
            onPressed: value.text.trim().isEmpty
                ? null
                : () => Navigator.of(context).pop(_controller.text),
            child: const Text('Save'),
          ),
        ),
      ],
    );
  }
}
