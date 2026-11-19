import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// The toast text for a failed archive or unarchive.
String archiveFailureMessage(
  ApiFailure error,
  Channel channel, {
  required bool archived,
}) {
  final action = archived ? 'archive' : 'unarchive';
  return switch (error.kind) {
    ApiFailureKind.forbidden =>
      'Only the channel owner or an admin can $action #${channel.name}.',
    ApiFailureKind.unknown || ApiFailureKind.parsing =>
      'Could not $action #${channel.name}. Please try again.',
    _ =>
      error.friendlyMessage.isEmpty
          ? 'Could not $action #${channel.name}'
          : error.friendlyMessage,
  };
}

/// The channel directory's archived channels, each with an Unarchive button.
class ArchivedChannelList extends ConsumerStatefulWidget {
  final String searchQuery;

  const ArchivedChannelList({super.key, this.searchQuery = ''});

  @override
  ConsumerState<ArchivedChannelList> createState() =>
      _ArchivedChannelListState();
}

class _ArchivedChannelListState extends ConsumerState<ArchivedChannelList> {
  final Set<String> _unarchiving = {};

  Future<void> _unarchive(Channel channel) async {
    final overlay = Overlay.of(context, rootOverlay: true);
    setState(() => _unarchiving.add(channel.id));
    final result = await ref
        .read(channelProvider.notifier)
        .archiveChannel(channel, archived: false);
    if (mounted) setState(() => _unarchiving.remove(channel.id));

    switch (result) {
      case Success<void>():
        AppToastService.showWith(
          overlay,
          type: AppToastType.success,
          message: '#${channel.name} was unarchived',
        );
      case Failure<void>(:final error):
        AppToastService.showWith(
          overlay,
          type: AppToastType.error,
          message: archiveFailureMessage(error, channel, archived: false),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final archivedState = ref.watch(archivedChannelsProvider);
    final colors = context.colors;
    final textTheme = context.textTheme;
    final query = widget.searchQuery.toLowerCase();

    if (archivedState.isLoading && !archivedState.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }
    if (archivedState.hasError && !archivedState.hasValue) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Couldn't load archived channels",
              style: textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.invalidate(archivedChannelsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final channels = (archivedState.value ?? const <Channel>[])
        .where(
          (c) =>
              query.isEmpty ||
              c.name.toLowerCase().contains(query) ||
              c.description.toLowerCase().contains(query),
        )
        .toList();

    if (channels.isEmpty) {
      return Center(
        child: Text(
          'No archived channels.',
          style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
        ),
      );
    }

    return ListView.builder(
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final channel = channels[index];
        final busy = _unarchiving.contains(channel.id);
        return ListTile(
          key: ValueKey('archived-channel-${channel.id}'),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 24.0,
            vertical: 8.0,
          ),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.archive_outlined,
              size: 20,
              color: colors.textSecondary,
            ),
          ),
          title: Text(
            channel.name,
            style: textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
          subtitle: channel.description.isNotEmpty
              ? Text(
                  channel.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                )
              : null,
          trailing: OutlinedButton(
            onPressed: busy ? null : () => _unarchive(channel),
            child: Text(busy ? 'Unarchiving…' : 'Unarchive'),
          ),
        );
      },
    );
  }
}
