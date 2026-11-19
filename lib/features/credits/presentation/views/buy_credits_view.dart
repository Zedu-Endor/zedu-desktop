import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class BuyCreditsView extends ConsumerStatefulWidget {
  const BuyCreditsView({super.key});

  @override
  ConsumerState<BuyCreditsView> createState() => _BuyCreditsViewState();
}

class _BuyCreditsViewState extends ConsumerState<BuyCreditsView> {
  String? _lastLoadedOrgId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCredits());
  }

  void _loadCredits([String? explicitOrgId, bool force = false]) {
    final orgId = explicitOrgId ?? _resolveOrgId();
    if (orgId != null &&
        orgId.isNotEmpty &&
        (force || orgId != _lastLoadedOrgId)) {
      _lastLoadedOrgId = orgId;
      ref.read(creditsNotifierProvider.notifier).load(orgId: orgId);
    }
  }

  String? _resolveOrgId() {
    final currentOrgId = ref.read(currentOrgIdProvider);
    if (currentOrgId.isNotEmpty) return currentOrgId;

    final workspaceOrgId = ref.read(workspaceProvider).selectedWorkspace?.id;
    if (workspaceOrgId != null && workspaceOrgId.isNotEmpty) {
      return workspaceOrgId;
    }

    final authOrgId = ref.read(authNotifierProvider).user?.currentOrg;
    if (authOrgId != null && authOrgId.isNotEmpty) {
      return authOrgId;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(currentOrgIdProvider, (previous, next) {
      if (next.isNotEmpty && previous != next) {
        _loadCredits(next);
      }
    });

    ref.listen<String?>(
      authNotifierProvider.select((s) => s.user?.currentOrg),
      (previous, next) {
        if (next != null && next.isNotEmpty && previous != next) {
          _loadCredits(next);
        }
      },
    );
    ref.listen<CreditsState>(creditsNotifierProvider, (previous, next) {
      if (next.successMessage != null &&
          previous?.successMessage != next.successMessage) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          AppToastService.show(
            context,
            type: AppToastType.success,
            message: next.successMessage!,
          );
        });
      }
      if (next.error != null && previous?.error != next.error) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          AppToastService.show(
            context,
            type: AppToastType.error,
            message: next.error!,
          );
        });
      }
    });

    final state = ref.watch(creditsNotifierProvider);
    final authUser = ref.watch(authNotifierProvider).user;
    final balance = ref.watch(orgCreditBalanceProvider);

    return ProfileSettingsShell(
      selectedSection: UserProfileSection.billing,
      onSectionSelected: (section) {
        ref.read(userProfileNotifierProvider.notifier).selectSection(section);
        context.go(AppRouter.profile);
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 32, 40, 48),
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProfileSectionHeader(
                  title: 'Billing & Plans',
                  subtitle:
                      'Purchase AI credits for your organization. All plans include AI-powered platform features.',
                  trailing: _BalanceChip(balance: balance),
                ),
                const SizedBox(height: 12),
                Text(
                  'All Plans',
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                if (state.isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(48),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (state.status == CreditsStatus.error)
                  _PackagesLoadError(
                    message: state.error,
                    onRetry: () => _loadCredits(null, true),
                  )
                else if (state.packages.isEmpty)
                  Text(
                    'No AI credit packages available.',
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  )
                else
                  CreditPackagesGrid(
                    packages: state.packages,
                    currentPlanSlug: authUser?.subscriptionPlanId,
                    purchasingPackageId: state.purchasingPackageId,
                    onPurchase: (package) => _onPurchase(context, package),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onPurchase(BuildContext context, CreditPackage package) async {
    if (package.name.toLowerCase() == 'enterprise') {
      await _openContactSales(context);
      return;
    }

    final user = ref.read(authNotifierProvider).user;
    if (user == null) return;

    final checkout = await ref
        .read(creditsNotifierProvider.notifier)
        .purchasePackage(package: package, email: user.email);

    if (!context.mounted || checkout == null) return;

    final uri = Uri.tryParse(checkout.checkoutSessionUrl);
    if (uri == null) {
      AppToastService.show(
        context,
        type: AppToastType.error,
        message: 'Invalid checkout URL returned by server.',
      );
      return;
    }

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (!launched && context.mounted) {
        AppToastService.show(
          context,
          type: AppToastType.error,
          message: 'Could not open payment page automatically.',
        );
      }
    } catch (e) {
      AppLogger.w('Could not launch credit checkout page', error: e);
      if (context.mounted) {
        AppToastService.show(
          context,
          type: AppToastType.error,
          message: 'Could not open the payment page. Please try again.',
        );
      }
    }
  }

  Future<void> _openContactSales(BuildContext context) async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(locator<AppConfig>().contactSalesUrl),
        mode: LaunchMode.platformDefault,
      );
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      AppToastService.show(
        context,
        type: AppToastType.error,
        message: 'Could not open the Contact Sales page.',
      );
    }
  }
}

/// Shown when the AI credit packages could not be loaded, with a way to try
/// again without leaving the page.
class _PackagesLoadError extends StatelessWidget {
  const _PackagesLoadError({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 40, color: colors.textHint),
            const SizedBox(height: 12),
            Text(
              "Couldn't load AI credit packages.",
              textAlign: TextAlign.center,
              style: context.textTheme.titleSmall?.copyWith(
                color: colors.textPrimary,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 4),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _BalanceChip extends StatelessWidget {
  const _BalanceChip({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colors.primaryBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.borderOutline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 18, color: colors.primary),
          const SizedBox(width: 8),
          Text(
            aiCreditsLabel(balance),
            style: context.textTheme.labelLarge?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
