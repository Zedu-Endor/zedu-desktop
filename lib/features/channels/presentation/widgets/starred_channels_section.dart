import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class StarredChannelsSection extends ConsumerStatefulWidget {
  const StarredChannelsSection({super.key});

  @override
  ConsumerState<StarredChannelsSection> createState() =>
      _StarredChannelsSectionState();
}

class _StarredChannelsSectionState
    extends ConsumerState<StarredChannelsSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(starredChannelProvider);
    final channels = ref
        .watch(workspaceChannelsProvider)
        .where((c) => state.ids.contains(c.id))
        .toList();
    final colors = context.colors;
    if (state.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: LinearProgressIndicator(
          semanticsLabel: 'Loading starred channels',
        ),
      );
    }
    if (state.error != null && !state.loaded) {
      return TextButton.icon(
        onPressed: () => ref.read(starredChannelProvider.notifier).retry(),
        icon: Icon(Icons.refresh, color: colors.onPrimary),
        label: Text(state.error!, style: TextStyle(color: colors.onPrimary)),
      );
    }
    if (channels.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          expanded: _expanded,
          child: ListTile(
            dense: true,
            leading: Icon(
              _expanded ? Icons.arrow_drop_down : Icons.arrow_right,
              color: colors.onPrimary,
              size: 20,
            ),
            title: Text(
              'Starred',
              style: context.textTheme.titleSmall?.copyWith(
                color: colors.onPrimary,
              ),
            ),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
        ),
        if (_expanded)
          for (final channel in channels) ChannelSidebarItem(channel: channel),
      ],
    );
  }
}

/// Both sidebar sections use the same selection path and conversation identity.
class ChannelSidebarItem extends ConsumerWidget {
  const ChannelSidebarItem({super.key, required this.channel});
  final Channel channel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final selected = ref.watch(selectedChannelProvider)?.id == channel.id;
    return ListTile(
      dense: true,
      selected: selected,
      selectedTileColor: colors.onPrimary.withValues(alpha: 0.12),
      leading: Icon(
        channel.isPrivate ? Icons.lock_outline : Icons.tag,
        size: 18,
        color: colors.onPrimary.withValues(alpha: 0.7),
      ),
      title: Text(
        channel.name,
        overflow: TextOverflow.ellipsis,
        style: context.textTheme.bodyMedium?.copyWith(color: colors.onPrimary),
      ),
      onTap: () {
        ref.read(selectedChannelIdProvider.notifier).select(channel.id);
      },
    );
  }
}
