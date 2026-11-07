import 'package:zedu/core/core.dart';

/// The pre-login explainer for Zedu Coin (ZDU).
///
/// It is read-only: a short introduction, a few expandable answers, and the
/// fluctuation notice. There is deliberately no price, wallet or purchase
/// action while ZDU is pre-launch.
class ZeduCoinPanel extends StatefulWidget {
  const ZeduCoinPanel({super.key});

  /// One question and its answer.
  static const faqs = <(String, String)>[
    (
      'What is ZDU?',
      'Zedu Learning’s blockchain payment token. At launch it will be how you '
          'pay for in-app purchases and subscription renewals.',
    ),
    (
      'When can I use it?',
      'Coming soon, when Zedu Learning launches. It isn’t available to buy or '
          'use yet.',
    ),
    ('What about the value?', 'Prices are subject to fluctuation.'),
    (
      'How do I pay today?',
      'Card payments for AI Credits continue as normal until ZDU launches.',
    ),
  ];

  @override
  State<ZeduCoinPanel> createState() => _ZeduCoinPanelState();
}

class _ZeduCoinPanelState extends State<ZeduCoinPanel> {
  final Set<int> _open = <int>{};

  void _toggle(int index) {
    setState(() {
      if (!_open.remove(index)) _open.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    return Container(
      key: const Key('zedu-coin-panel'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.onPrimary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.borderOutline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.primaryBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.toll_outlined,
                  color: colors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Zedu Coin (ZDU)',
                  style: textTheme.titleMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              _StatusChip(label: 'Pre-launch'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Zedu Learning’s blockchain payment token for in-app purchases and '
            'subscription renewals.',
            style: textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < ZeduCoinPanel.faqs.length; i++)
            _FaqRow(
              question: ZeduCoinPanel.faqs[i].$1,
              answer: ZeduCoinPanel.faqs[i].$2,
              isOpen: _open.contains(i),
              onTap: () => _toggle(i),
            ),
          const SizedBox(height: 12),
          Text(
            'Prices are subject to fluctuation.',
            style: textTheme.bodySmall?.copyWith(
              fontSize: 12,
              color: colors.textHint,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.primaryBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: context.textTheme.labelSmall?.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: colors.primary,
        ),
      ),
    );
  }
}

class _FaqRow extends StatelessWidget {
  const _FaqRow({
    required this.question,
    required this.answer,
    required this.isOpen,
    required this.onTap,
  });

  final String question;
  final String answer;
  final bool isOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: 1, color: colors.divider),
        InkWell(
          key: ValueKey('zedu-coin-faq-$question'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    question,
                    style: textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  isOpen ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: colors.textHint,
                ),
              ],
            ),
          ),
        ),
        if (isOpen)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              answer,
              style: textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                color: colors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}
