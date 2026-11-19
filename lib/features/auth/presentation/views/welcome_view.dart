import 'package:zedu/core/core.dart';

/// Shown on the first launch, before sign-in: what Zedu is and what it does,
/// with Get Started leading to the usual login screen.
class WelcomeView extends StatefulWidget {
  const WelcomeView({super.key});

  /// Features that exist in the desktop app today.
  static const features = [
    (
      icon: Icons.tag,
      title: 'Channels',
      description: 'Keep conversations organised by team, project or topic.',
    ),
    (
      icon: Icons.chat_bubble_outline,
      title: 'Direct messages',
      description: 'Talk one-to-one or in small groups.',
    ),
    (
      icon: Icons.headphones_outlined,
      title: 'Buzz calls',
      description: 'Jump on a quick call with your teammates.',
    ),
  ];

  @override
  State<WelcomeView> createState() => _WelcomeViewState();
}

class _WelcomeViewState extends State<WelcomeView> {
  bool _leaving = false;

  Future<void> _getStarted() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    try {
      await locator<SecureStorageService>().writeData(
        AppRouter.welcomeSeenKey,
        'true',
      );
    } catch (_) {
      // Not remembering it only means the welcome shows again next time.
    }
    if (mounted) context.go(AppRouter.login);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: Column(
                children: [
                  Semantics(
                    label: 'Zedu',
                    image: true,
                    child: Image.asset(
                      'assets/pngs/zedu_logo.png',
                      width: 83,
                      height: 31,
                    ),
                  ),
                  context.gapV(40),
                  Text(
                    'Welcome to Zedu',
                    textAlign: TextAlign.center,
                    style: context.textTheme.headlineMedium,
                  ),
                  context.gapV(12),
                  Text(
                    'Chat, call and work together with your team in one place.',
                    textAlign: TextAlign.center,
                    style: context.textTheme.bodyLarge?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  context.gapV(40),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      for (final feature in WelcomeView.features)
                        _FeatureCard(
                          icon: feature.icon,
                          title: feature.title,
                          description: feature.description,
                        ),
                    ],
                  ),
                  context.gapV(40),
                  SizedBox(
                    width: 280,
                    child: AppButton(
                      label: 'Get Started',
                      loading: _leaving,
                      onPressed: _getStarted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 260,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.primaryBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.borderOutline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.primary, size: 24),
          context.gapV(12),
          Text(
            title,
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          context.gapV(4),
          Text(
            description,
            style: context.textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
