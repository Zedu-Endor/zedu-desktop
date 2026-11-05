import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// The cross-workspace inbox: every workspace's conversations in one list, so
/// a user can catch up without switching workspaces one by one (#2541).
class InboxDialog extends ConsumerWidget {
  const InboxDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(inboxProvider);
    final unreadOnly = ref.watch(inboxUnreadFilterProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(unreadOnly: unreadOnly),
            const Divider(height: 1),
            Flexible(
              child: snapshot.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => _InboxMessage(
                  icon: Icons.error_outline,
                  title: 'The inbox could not be loaded',
                  detail: '$error',
                  onRetry: () => ref.read(inboxProvider.notifier).refresh(),
                ),
                data: (data) =>
                    _InboxList(snapshot: data, unreadOnly: unreadOnly),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.unreadOnly});

  final bool unreadOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(inboxUnreadCountProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      child: Row(
        children: [
          Text(
            'Inbox',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (unread > 0) ...[
            const SizedBox(width: 8),
            Semantics(
              label: '$unread unread',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: context.colors.error,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$unread',
                  style: context.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
          const Spacer(),
          TextButton.icon(
            onPressed: () =>
                ref.read(inboxUnreadFilterProvider.notifier).toggle(),
            icon: Icon(
              unreadOnly ? Icons.filter_alt : Icons.filter_alt_outlined,
              size: 18,
            ),
            label: Text(unreadOnly ? 'Unread only' : 'All'),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => ref.read(inboxProvider.notifier).refresh(),
          ),
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _InboxList extends ConsumerWidget {
  const _InboxList({required this.snapshot, required this.unreadOnly});

  final InboxSnapshot snapshot;
  final bool unreadOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = unreadOnly ? snapshot.unreadItems : snapshot.items;

    if (items.isEmpty) {
      return _InboxMessage(
        icon: Icons.inbox_outlined,
        title: unreadOnly ? 'Nothing unread' : 'Your inbox is empty',
        detail: unreadOnly
            ? 'Every conversation across your workspaces has been read.'
            : 'Conversations from all your workspaces will appear here.',
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: items.length + (snapshot.hasFailures ? 1 : 0),
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (snapshot.hasFailures && index == 0) {
          return _FailureBanner(workspaces: snapshot.failedWorkspaces);
        }
        final item = items[index - (snapshot.hasFailures ? 1 : 0)];
        return InboxRow(item: item);
      },
    );
  }
}

/// Names the workspaces that could not be read, so a partial inbox never
/// silently looks like a complete one.
class _FailureBanner extends StatelessWidget {
  const _FailureBanner({required this.workspaces});

  final List<String> workspaces;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: context.colors.error.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Text(
        workspaces.length == 1
            ? 'Could not read ${workspaces.single}. Other workspaces are shown.'
            : 'Could not read ${workspaces.length} workspaces: '
                  '${workspaces.join(', ')}. The rest are shown.',
        style: context.textTheme.bodySmall,
      ),
    );
  }
}

class _InboxMessage extends StatelessWidget {
  const _InboxMessage({
    required this.icon,
    required this.title,
    required this.detail,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: context.colors.textSecondary),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ],
      ),
    );
  }
}
