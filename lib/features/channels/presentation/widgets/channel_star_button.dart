import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class ChannelStarButton extends ConsumerWidget {
  const ChannelStarButton({super.key, required this.channel});
  final Channel channel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(starredChannelProvider);
    ref.listen(starredChannelProvider.select((s) => s.error), (_, error) {
      if (error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      }
    });
    final starred = state.ids.contains(channel.id);
    return IconButton(
      tooltip: starred ? 'Unstar channel' : 'Star channel',
      icon: Icon(
        starred ? Icons.star_rounded : Icons.star_border_rounded,
        size: 20,
      ),
      color: starred ? context.colors.primary : context.colors.textSecondary,
      style: IconButton.styleFrom(
        minimumSize: const Size(32, 32),
        padding: const EdgeInsets.all(6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        hoverColor: context.colors.textPrimary.withValues(alpha: 0.08),
        focusColor: context.colors.primary.withValues(alpha: 0.12),
      ),
      onPressed: state.loaded && !state.isSaving
          ? () => ref.read(starredChannelProvider.notifier).toggle(channel)
          : null,
    );
  }
}
