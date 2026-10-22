import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class DmChatArea extends ConsumerStatefulWidget {
  final DmConversation conversation;

  const DmChatArea({super.key, required this.conversation});

  @override
  ConsumerState<DmChatArea> createState() => _DmChatAreaState();
}

class _DmChatAreaState extends ConsumerState<DmChatArea> {
  bool _isDragging = false;
  final _composerKey = GlobalKey<DmMessageComposerState>();

  String get _recipientHandle => widget.conversation.dmHandle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DropTarget(
      onDragDone: (detail) {
        _composerKey.currentState?.addFiles(detail.files);
        setState(() => _isDragging = false);
      },
      onDragEntered: (detail) {
        setState(() => _isDragging = true);
      },
      onDragExited: (detail) {
        setState(() => _isDragging = false);
      },
      child: Container(
        color: colors.onPrimary,
        child: Stack(
          children: [
            Column(
              children: [
                _DmChatHeader(conversation: widget.conversation),
                Expanded(
                  child: Consumer(
                    builder: (context, ref, child) {
                      final historyState = ref.watch(
                        chatHistoryProvider(widget.conversation.channelId),
                      );
                      final messages = historyState.messages;

                      return NotificationListener<ScrollNotification>(
                        onNotification: (ScrollNotification scrollInfo) {
                          if (!historyState.isLoading &&
                              historyState.hasMore &&
                              scrollInfo.metrics.pixels >=
                                  scrollInfo.metrics.maxScrollExtent * 0.8) {
                            ref
                                .read(
                                  chatHistoryProvider(
                                    widget.conversation.channelId,
                                  ),
                                )
                                .loadMore();
                          }
                          return false;
                        },
                        child: CustomScrollView(
                          reverse: true,
                          slivers: [
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate((
                                  context,
                                  index,
                                ) {
                                  final msg = messages[index];
                                  return _MessageBubble(
                                    message: msg,
                                    conversation: widget.conversation,
                                    channelId: widget.conversation.channelId,
                                  );
                                }, childCount: messages.length),
                              ),
                            ),
                            if (historyState.isLoading)
                              const SliverToBoxAdapter(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                              ),
                            if (!historyState.hasMore)
                              SliverToBoxAdapter(
                                child: DmProfileCard(
                                  conversation: widget.conversation,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                DmMessageComposer(
                  key: _composerKey,
                  recipientName: _recipientHandle,
                  channelId: widget.conversation.channelId,
                  participants: widget.conversation.participants,
                ),
              ],
            ),

            // FULL PAGE MODE INJECTION
            Consumer(
              builder: (context, ref, child) {
                final activeCall = ref.watch(activeCallProvider);
                if (activeCall.state.status == CallStatus.active &&
                    activeCall.state.isFullPage) {
                  return const Positioned.fill(child: BuzzMeetingView());
                }
                return const SizedBox.shrink();
              },
            ),

            // FLOATING / PIP INJECTION
            Consumer(
              builder: (context, ref, child) {
                final activeCall = ref.watch(activeCallProvider);
                if (activeCall.state.status == CallStatus.active &&
                    !activeCall.state.isFullPage) {
                  return const BuzzMeetingView();
                }
                return const SizedBox.shrink();
              },
            ),

            // INCOMING CALL MODAL
            const IncomingCallModal(),

            // RINGING STATE OVERLAY (Caller)
            Consumer(
              builder: (context, ref, child) {
                final activeCall = ref.watch(activeCallProvider);
                if (activeCall.state.status == CallStatus.calling) {
                  return Positioned(
                    top: 24,
                    right: 24,
                    child: Material(
                      color: Colors.transparent,
                      elevation: 8,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 320,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.divider),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Calling...',
                                    style: TextStyle(
                                      color: colors.textHint,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    activeCall.state.remoteUserName ??
                                        'Unknown',
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.call_end),
                              color: Colors.red,
                              onPressed: () {
                                ref
                                    .read(activeCallProvider.notifier)
                                    .cancelCall();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            if (_isDragging)
              Positioned.fill(
                child: Container(
                  color: colors.primary.withValues(alpha: 0.2),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Drop files to attach',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DmChatHeader extends StatelessWidget {
  final DmConversation conversation;

  const _DmChatHeader({required this.conversation});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final participantInitial = conversation.displayName.trim().isEmpty
        ? '?'
        : conversation.displayName.trim()[0].toUpperCase();

    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: colors.primary,
            backgroundImage: conversation.effectiveAvatarUrl != null
                ? NetworkImage(conversation.effectiveAvatarUrl!)
                : null,
            child: conversation.effectiveAvatarUrl == null
                ? Text(
                    participantInitial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Text(
            conversation.displayName,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: colors.textPrimary,
            ),
          ),
          const Spacer(),
          Consumer(
            builder: (context, ref, child) {
              return InkWell(
                onTap: () {
                  ref
                      .read(activeCallProvider.notifier)
                      .initiateCall(
                        remoteUserId: conversation.participantId,
                        remoteUserName: conversation.displayName,
                        channelId: conversation.channelId,
                        remoteAvatarUrl: conversation.effectiveAvatarUrl,
                      );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.divider),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.headphones_outlined,
                    size: 18,
                    color: colors.textPrimary,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Icon(Icons.more_vert, color: colors.textHint),
        ],
      ),
    );
  }
}

class _MessageBubble extends ConsumerWidget {
  final Map<String, dynamic> message;
  final DmConversation conversation;
  final String channelId;

  const _MessageBubble({
    required this.message,
    required this.conversation,
    required this.channelId,
  });

  TextSpan _parseRichText(String text, TextStyle defaultStyle) {
    if (text.isEmpty) return TextSpan(style: defaultStyle, text: '');

    final boldRegex = RegExp(r'\*\*(.*?)\*\*', dotAll: true);
    final italicRegex = RegExp(r'(?<!\*)\*(.*?)\*(?!\*)', dotAll: true);
    final strikeRegex = RegExp(r'~~(.*?)~~', dotAll: true);
    final codeRegex = RegExp(r'`(.*?)`', dotAll: true);

    final allPatterns = [boldRegex, italicRegex, strikeRegex, codeRegex];
    final combined = RegExp(
      allPatterns.map((r) => r.pattern).join('|'),
      dotAll: true,
    );

    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in combined.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, match.start),
            style: defaultStyle,
          ),
        );
      }

      final raw = match.group(0)!;
      if (boldRegex.hasMatch(raw)) {
        final inner =
            match.group(1) ?? boldRegex.firstMatch(raw)?.group(1) ?? raw;
        spans.add(
          TextSpan(
            text: inner,
            style: defaultStyle.copyWith(fontWeight: FontWeight.bold),
          ),
        );
      } else if (strikeRegex.hasMatch(raw)) {
        final inner = strikeRegex.firstMatch(raw)?.group(1) ?? raw;
        spans.add(
          TextSpan(
            text: inner,
            style: defaultStyle.copyWith(
              decoration: TextDecoration.lineThrough,
            ),
          ),
        );
      } else if (codeRegex.hasMatch(raw)) {
        final inner = codeRegex.firstMatch(raw)?.group(1) ?? raw;
        spans.add(
          TextSpan(
            text: inner,
            style: defaultStyle.copyWith(
              fontFamily: 'monospace',
              backgroundColor: const Color(0x1A6458F5),
              color: const Color(0xFF6458F5),
            ),
          ),
        );
      } else if (italicRegex.hasMatch(raw)) {
        final inner = italicRegex.firstMatch(raw)?.group(1) ?? raw;
        spans.add(
          TextSpan(
            text: inner,
            style: defaultStyle.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      } else {
        spans.add(TextSpan(text: raw, style: defaultStyle));
      }
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: defaultStyle));
    }

    return TextSpan(style: defaultStyle, children: spans);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final history = ref.watch(chatHistoryProvider(channelId));
    final isMe = history.isMyMessage(message);
    final content = message['content'] as String? ?? '';
    final createdAt =
        DateTime.tryParse(message['created_at']?.toString() ?? '')?.toLocal() ??
        DateTime.now();
    final status = message['status'] as String?;
    final messageId = message['id'] as String? ?? '';

    final hour = createdAt.hour > 12
        ? createdAt.hour - 12
        : (createdAt.hour == 0 ? 12 : createdAt.hour);
    final minute = createdAt.minute.toString().padLeft(2, '0');
    final period = createdAt.hour >= 12 ? 'PM' : 'AM';
    final timeString = '$hour:$minute $period';

    final senderName = isMe
        ? history.currentUserName
        : conversation.displayName;

    final senderAvatarUrl = isMe
        ? history.currentUserAvatarUrl
        : conversation.effectiveAvatarUrl;

    final senderInitial = senderName.isNotEmpty
        ? senderName[0].toUpperCase()
        : '?';

    final List<dynamic> media = (message['media'] as List<dynamic>?) ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 15,
              backgroundColor: colors.primary,
              backgroundImage:
                  senderAvatarUrl != null && senderAvatarUrl.isNotEmpty
                  ? NetworkImage(senderAvatarUrl)
                  : null,
              child: senderAvatarUrl == null || senderAvatarUrl.isEmpty
                  ? Text(
                      senderInitial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        senderName,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeString,
                        style: TextStyle(color: colors.textHint, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (content.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isMe
                          ? colors.primary
                          : colors.onPrimary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: RichText(
                      text: _parseRichText(
                        content,
                        TextStyle(
                          color: isMe ? Colors.white : colors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                if (media.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: content.isNotEmpty ? 8 : 0),
                    child: _AttachmentBubbleList(media: media, isMe: isMe),
                  ),
                if (isMe && status != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: status == 'failed'
                        ? GestureDetector(
                            onTap: () {
                              ref
                                  .read(chatHistoryProvider(channelId))
                                  .retryMessage(messageId);
                            },
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

class _AttachmentBubbleList extends StatelessWidget {
  final List<dynamic> media;
  final bool isMe;

  const _AttachmentBubbleList({required this.media, required this.isMe});

  void _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Widget _buildGenericFile(
    String fileName,
    String fileLink,
    bool isImage,
    BuildContext context,
  ) {
    final colors = context.colors;
    return GestureDetector(
      onTap: fileLink.isNotEmpty ? () => _launchUrl(fileLink) : null,
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isMe
              ? colors.primary.withValues(alpha: 0.15)
              : colors.onPrimary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isMe
                ? colors.primary.withValues(alpha: 0.3)
                : colors.divider,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isImage ? Icons.image_rounded : Icons.insert_drive_file_rounded,
              color: isMe ? colors.primary : colors.textPrimary,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              fileName,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: isMe ? WrapAlignment.end : WrapAlignment.start,
      children: media.map((item) {
        final String fileName = (item['file_name'] ?? 'Attachment').toString();
        final String fileLink = (item['file_link'] ?? '').toString();
        final isImage = [
          'png',
          'jpg',
          'jpeg',
          'gif',
          'webp',
        ].contains((item['file_type'] ?? '').toString().toLowerCase());

        if (isImage && fileLink.isNotEmpty) {
          final isNetwork = fileLink.startsWith('http');

          return GestureDetector(
            onTap: () => _launchUrl(fileLink),
            child: Container(
              width: 250,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colors.divider),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: isNetwork
                    ? Image.network(
                        fileLink,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildGenericFile(
                              fileName,
                              fileLink,
                              isImage,
                              context,
                            ),
                      )
                    : Image.asset(
                        fileLink,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildGenericFile(
                              fileName,
                              fileLink,
                              isImage,
                              context,
                            ),
                      ),
              ),
            ),
          );
        }

        return _buildGenericFile(fileName, fileLink, isImage, context);
      }).toList(),
    );
  }
}
