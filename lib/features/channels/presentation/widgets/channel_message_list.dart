import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// The messages of a channel, newest at the bottom. Shows [empty] when the
/// channel has no messages yet.
class ChannelMessageList extends ConsumerStatefulWidget {
  const ChannelMessageList({
    super.key,
    required this.channelId,
    required this.empty,
  });

  final String channelId;
  final Widget empty;

  @override
  ConsumerState<ChannelMessageList> createState() => _ChannelMessageListState();
}

class _ChannelMessageListState extends ConsumerState<ChannelMessageList> {
  final _search = TextEditingController();

  /// What the search box filters the loaded messages by (Ziki #2849).
  String _query = '';

  String get channelId => widget.channelId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(ChannelMessage message, String query) =>
      message.text.toLowerCase().contains(query) ||
      message.senderName.toLowerCase().contains(query);

  void _clearSearch() {
    _search.clear();
    setState(() => _query = '');
  }

  Widget _searchBar(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: SizedBox(
        height: 36,
        child: TextField(
          key: const ValueKey('channel-message-search'),
          controller: _search,
          onChanged: (value) => setState(() => _query = value.trim()),
          style: TextStyle(color: colors.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search messages in this channel',
            hintStyle: TextStyle(color: colors.textHint, fontSize: 13),
            prefixIcon: Icon(Icons.search, size: 18, color: colors.textHint),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: Icon(Icons.close, size: 16, color: colors.textHint),
                    onPressed: _clearSearch,
                  ),
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: colors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: colors.divider),
            ),
          ),
        ),
      ),
    );
  }

  /// The search box above [body]: the list, or what to show instead of it.
  Widget _withSearch(BuildContext context, Widget body) => Column(
    children: [
      _searchBar(context),
      Expanded(child: body),
    ],
  );

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
            if (allMessages.isEmpty) return widget.empty;
            final query = _query.toLowerCase();
            if (query.isEmpty) {
              return _withSearch(
                context,
                _buildList(context, ref, allMessages),
              );
            }
            // Searching covers the messages loaded so far.
            final found = allMessages.where((m) => _matches(m, query)).toList();
            return _withSearch(
              context,
              found.isEmpty
                  ? Center(
                      child: Text(
                        'No messages match "$_query"',
                        style: TextStyle(color: context.colors.textHint),
                      ),
                    )
                  : _buildList(context, ref, found),
            );
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
        final tile = ChannelMessageTile(
          message: message,
          onRetry: message.id != null
              ? () => ref
                    .read(chatHistoryProvider(channelId))
                    .retryMessage(message.id!)
              : null,
        );
        // Newest first, so the next index is the older neighbour. A day
        // starts at the oldest message or where the older one is another day.
        final time = message.createdAt;
        final isOldest = index == messages.length - 1;
        final olderTime = isOldest ? null : messages[index + 1].createdAt;
        final startsDay =
            time != null &&
            (isOldest ||
                (olderTime != null && !DateUtils.isSameDay(time, olderTime)));
        if (!startsDay) return tile;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ChannelDayDivider(label: channelDayLabel(time)),
            tile,
          ],
        );
      },
    );
  }
}

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// The label of the divider above a day's first message: "Today",
/// "Yesterday", the weekday within the last week, otherwise the date, with
/// the year only when it isn't this year.
String channelDayLabel(DateTime day, {DateTime? now}) {
  final today = now ?? DateTime.now();
  // Whole days between the calendar dates, unaffected by DST changes.
  final daysAgo = DateTime.utc(
    today.year,
    today.month,
    today.day,
  ).difference(DateTime.utc(day.year, day.month, day.day)).inDays;
  if (daysAgo == 0) return 'Today';
  if (daysAgo == 1) return 'Yesterday';
  final weekday = _weekdays[day.weekday - 1];
  if (daysAgo > 1 && daysAgo < 7) return weekday;
  final date = '$weekday, ${_months[day.month - 1]} ${day.day}';
  return day.year == today.year ? date : '$date, ${day.year}';
}

/// A line with the day's label, above the first message of each day.
class ChannelDayDivider extends StatelessWidget {
  const ChannelDayDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      child: Semantics(
        header: true,
        child: Row(
          children: [
            Expanded(child: Divider(color: colors.divider)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
            ),
            Expanded(child: Divider(color: colors.divider)),
          ],
        ),
      ),
    );
  }
}

class ChannelMessageTile extends StatelessWidget {
  const ChannelMessageTile({super.key, required this.message, this.onRetry});

  final ChannelMessage message;
  final VoidCallback? onRetry;

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
                MessageLinkScope(
                  builder: (context, links) => SelectableText.rich(
                    buildInlineMarkdownSpan(
                      message.text,
                      TextStyle(fontSize: 15, color: colors.textPrimary),
                      plainText: links.span,
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
