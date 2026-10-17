import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class WorkspaceSwitcherHeader extends ConsumerWidget {
  const WorkspaceSwitcherHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final workspaceState = ref.watch(workspaceProvider);
    final selectedWorkspace = workspaceState.selectedWorkspace;

    if (selectedWorkspace == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _showWorkspaceSwitcher(context),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      selectedWorkspace.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colors.onPrimary,
                        letterSpacing: 0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down,
                    color: colors.onPrimary.withValues(alpha: 0.7),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Create channel',
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (_) => const CreateChannelModal(),
              );
            },
            icon: Icon(
              Icons.add,
              color: colors.onPrimary.withValues(alpha: 0.7),
              size: 20,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  void _showWorkspaceSwitcher(BuildContext context) {
    final colors = context.colors;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'WorkspaceSwitcher',
      barrierColor: colors.textPrimary.withValues(alpha: 0.26),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) {
        return const Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: EdgeInsets.only(top: 60, left: 16),
            child: WorkspaceSwitcherList(),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: anim1,
            alignment: Alignment.topLeft,
            child: child,
          ),
        );
      },
    );
  }
}
