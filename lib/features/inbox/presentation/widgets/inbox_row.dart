import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// One conversation in the inbox. Opening it switches to the workspace the
/// conversation belongs to, then selects it, so the user never has to find the
/// workspace themselves.
class InboxRow extends ConsumerWidget {
  const InboxRow({super.key, required this.item});

  final InboxItem item;

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final workspaces = ref.read(workspaceProvider).workspaces;
    final target = workspaces
        .where((workspace) => workspace.id == item.workspaceId)
        .firstOrNull;

    Navigator.of(context).pop();

    if (target != null) {
      await ref.read(workspaceProvider.notifier).switchWorkspace(target);
    }

    final activeChat = ref.read(activeChatProvider.notifier);
    switch (item.kind) {
      case InboxItemKind.groupMessage:
        activeChat.selectGroupDm(item.channelId);
      case InboxItemKind.directMessage:
        activeChat.selectDirectMessage(item.participantId);
    }
    ref.read(homeSidebarProvider.notifier).setType(HomeSidebarType.dms);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      button: true,
      label: item.isUnread
          ? '${item.title} in ${item.workspaceName}, ${item.unreadCount} unread'
          : '${item.title} in ${item.workspaceName}',
      child: InkWell(
        onTap: () => _open(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                item.kind == InboxItemKind.groupMessage
                    ? Icons.groups_outlined
                    : Icons.person_outline,
                size: 20,
                color: context.colors.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.textTheme.bodyMedium?.copyWith(
                              fontWeight: item.isUnread
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // The workspace each row came from: the whole point of
                        // a single inbox is knowing where something is.
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: context.colors.borderOutline,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.workspaceName,
                            style: context.textTheme.labelSmall?.copyWith(
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (item.preview.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (item.isUnread) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.error,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${item.unreadCount}',
                    style: context.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
