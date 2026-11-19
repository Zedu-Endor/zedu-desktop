import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class UserMenuButton extends ConsumerWidget {
  const UserMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final menuState = ref.watch<UserMenuState>(userMenuStateProvider);
    final notificationsPaused = ref.watch(
      notificationSettingsProvider.select((settings) => settings.isDndActive),
    );

    return GestureDetector(
      onTap: () {
        showDialog<void>(
          context: context,
          // The card is anchored beside the rail, so it must not dim the whole
          // window: a transparent barrier still closes it on an outside tap.
          barrierColor: Colors.transparent,
          builder: (context) => const UserMenuDialog(),
        );
      },
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 48,
              height: 48,
              color: colors.sidebar,
              child: Icon(Icons.person, color: colors.onPrimary, size: 32),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: menuState.isAway ? colors.textHint : colors.success,
                shape: BoxShape.circle,
                border: Border.all(color: colors.sidebar, width: 2),
              ),
            ),
          ),
          if (notificationsPaused)
            Positioned(
              top: 0,
              right: 0,
              child: Tooltip(
                message: 'Notifications paused',
                child: Container(
                  key: const ValueKey('user_menu_paused_badge'),
                  width: 17,
                  height: 17,
                  decoration: BoxDecoration(
                    color: colors.background,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.sidebar, width: 1.5),
                  ),
                  child: Icon(
                    Icons.notifications_off_outlined,
                    size: 11,
                    color: colors.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
