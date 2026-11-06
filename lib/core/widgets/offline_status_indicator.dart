import 'package:zedu/core/core.dart';

/// A lightweight, accessible banner that displays when the desktop app
/// detects that network connectivity has been lost.
///
/// It listens to [networkStatusProvider] and automatically hides when online.
class OfflineStatusIndicator extends ConsumerWidget {
  const OfflineStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(networkStatusProvider);
    final isOffline = status == NetworkStatus.offline;

    final colors = context.colors;

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: isOffline
          ? Container(
              key: const Key('offline_status_indicator'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: colors.errorBg,
                border: Border(
                  bottom: BorderSide(
                    color: colors.error.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off_rounded, size: 16, color: colors.error),
                  const SizedBox(width: 8),
                  Text(
                    'You are offline. Reconnecting...',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colors.error,
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    key: const Key('offline_retry_button'),
                    onTap: () {
                      ref
                          .read(networkStatusProvider.notifier)
                          .checkReachability();
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      child: Text(
                        'Retry',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          color: colors.error,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
