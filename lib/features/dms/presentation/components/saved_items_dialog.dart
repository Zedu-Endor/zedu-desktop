import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// "Saved items": every message this person saved, most recently saved first.
///
/// The list is local to this computer and shared across conversations, so a
/// message saved in one DM can be found from another. Removing an entry only
/// forgets the save; the message itself is never touched.
class SavedItemsDialog extends ConsumerWidget {
  const SavedItemsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final store = ref.watch(savedMessagesStoreProvider);
    final items = store.items;
    final now = DateTime.now();

    return AlertDialog(
      title: const Text('Saved items'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!store.isLoaded)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (items.isEmpty)
              const Text(
                'No saved messages yet. Hover over a message and choose '
                'Save to Saved items.',
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: colors.divider),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      isThreeLine: true,
                      leading: Icon(Icons.bookmark, color: colors.primary),
                      title: Text(item.conversationName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.content,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item.senderName} · Saved ${savedAtLabel(item.savedAt, now)}',
                            style: context.textTheme.bodySmall?.copyWith(
                              color: colors.textHint,
                            ),
                          ),
                        ],
                      ),
                      trailing: Tooltip(
                        message: 'Remove from Saved items',
                        child: IconButton(
                          icon: const Icon(Icons.bookmark_remove_outlined),
                          iconSize: 20,
                          onPressed: () => store.remove(item.id),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

const _monthNames = [
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

/// When a message was saved, in the clock format the message bubbles use:
/// "today at 2:32 PM", "yesterday at 9:05 AM", "Nov 4 at 6:10 PM".
String savedAtLabel(DateTime savedAt, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final savedDay = DateTime(savedAt.year, savedAt.month, savedAt.day);
  final daysApart = today.difference(savedDay).inDays;

  final hour = savedAt.hour > 12
      ? savedAt.hour - 12
      : (savedAt.hour == 0 ? 12 : savedAt.hour);
  final minute = savedAt.minute.toString().padLeft(2, '0');
  final period = savedAt.hour >= 12 ? 'PM' : 'AM';
  final time = '$hour:$minute $period';

  if (daysApart == 0) return 'today at $time';
  if (daysApart == 1) return 'yesterday at $time';
  return '${_monthNames[savedAt.month - 1]} ${savedAt.day} at $time';
}
