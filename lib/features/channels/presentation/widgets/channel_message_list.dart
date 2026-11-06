import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// The messages of a channel, newest at the bottom. Shows [empty] when the
/// channel has no messages yet.
class ChannelMessageList extends ConsumerWidget {
  const ChannelMessageList({
    super.key,
    required this.channelId,
    required this.empty,
  });

  final String channelId;
  final Widget empty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              : _buildList(context, ref, pendingMessages),
          error: (_, _) => pendingMessages.isEmpty
              ? Center(
                  child: TextButton(
                    onPressed: () =>
                        ref.invalidate(channelHistoryProvider(channelId)),
                    child: const Text("Couldn't load messages. Retry"),
                  ),
                )
              : _buildList(context, ref, pendingMessages),
          data: (serverMessages) {
            final allMessages = [...pendingMessages, ...serverMessages];
            return allMessages.isEmpty
                ? empty
                : _buildList(context, ref, allMessages);
          },
        );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<ChannelMessage> messages,
  ) {
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return ChannelMessageTile(
          message: message,
          channelId: channelId,
          onRetry: message.id != null
              ? () => ref
                    .read(chatHistoryProvider(channelId))
                    .retryMessage(message.id!)
              : null,
        );
      },
    );
  }
}

class ChannelMessageTile extends StatelessWidget {
  const ChannelMessageTile({
    super.key,
    required this.message,
    this.onRetry,
    this.channelId,
  });

  final ChannelMessage message;
  final VoidCallback? onRetry;

  /// The channel the message is in. Needed to save it or set a reminder on
  /// it; when absent the message simply has no menu.
  final String? channelId;

  /// Null for a message the server does not have yet, or when the channel is
  /// unknown: neither can be saved.
  SavedTarget? get _target {
    final id = message.id;
    final channel = channelId;
    if (id == null || id.isEmpty || channel == null || channel.isEmpty) {
      return null;
    }
    if (message.status != null) return null;
    return SavedTarget(channelId: channel, threadId: id);
  }

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
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? Text(initial, style: TextStyle(color: colors.onPrimary))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
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
                const SizedBox(height: 4),
                _ChannelMessageMenu(
                  target: _target,
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

/// Adds Save for later and Remind me about this to a channel message. The
/// menu appears on every message, the user's own and other people's alike.
class _ChannelMessageMenu extends ConsumerStatefulWidget {
  const _ChannelMessageMenu({required this.target, required this.child});

  final SavedTarget? target;
  final Widget child;

  @override
  ConsumerState<_ChannelMessageMenu> createState() =>
      _ChannelMessageMenuState();
}

class _ChannelMessageMenuState extends ConsumerState<_ChannelMessageMenu> {
  final _menuKey = GlobalKey<PopupMenuButtonState<String>>();
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final target = widget.target;
    if (target == null) return widget.child;

    final isSaved = ref.watch(savedKeysProvider).contains(target.key);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onSecondaryTap: () => _menuKey.currentState?.showButtonMenu(),
        onLongPress: () => _menuKey.currentState?.showButtonMenu(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: widget.child),
            Opacity(
              opacity: _hovered ? 1 : 0,
              child: PopupMenuButton<String>(
                key: _menuKey,
                tooltip: 'Message actions',
                icon: const Icon(Icons.more_horiz, size: 18),
                onSelected: (value) =>
                    handleSavedMenuAction(context, ref, value, target),
                itemBuilder: (_) => savedMenuEntries(isSaved: isSaved),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
