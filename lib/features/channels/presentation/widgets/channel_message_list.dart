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
    return ref
        .watch(channelHistoryProvider(channelId))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: TextButton(
              onPressed: () =>
                  ref.invalidate(channelHistoryProvider(channelId)),
              child: const Text("Couldn't load messages. Retry"),
            ),
          ),
          data: (messages) => messages.isEmpty
              ? empty
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) =>
                      ChannelMessageTile(message: messages[index]),
                ),
        );
  }
}

class ChannelMessageTile extends StatelessWidget {
  const ChannelMessageTile({super.key, required this.message});

  final ChannelMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final avatarUrl = message.avatarUrl;
    final time = message.createdAt;
    final trimmedName = message.senderName.trim();
    final initial = trimmedName.isNotEmpty
        ? trimmedName.characters.first.toUpperCase()
        : '?';

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
                MessageLinkScope(
                  builder: (context, links) => SelectableText.rich(
                    links.span(
                      message.text,
                      TextStyle(fontSize: 15, color: colors.textPrimary),
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
