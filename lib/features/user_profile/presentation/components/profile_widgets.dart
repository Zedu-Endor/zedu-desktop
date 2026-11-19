import 'package:zedu/core/core.dart';

class ProfileFieldLabel extends StatelessWidget {
  const ProfileFieldLabel(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: context.textTheme.labelSmall?.copyWith(
        color: const Color(0xFF6B7280),
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class SquareIconButton extends StatelessWidget {
  const SquareIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.size = 32,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        excludeFromSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              icon,
              size: size * 0.56,
              color: const Color(0xFF374151),
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileStatusPill extends StatelessWidget {
  const ProfileStatusPill({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final trimmed = status.trim();
    final lower = trimmed.toLowerCase();
    final isActive = lower == 'active';
    final isPending = lower == 'pending';

    final Color bgColor;
    final Color dotColor;
    final Color textColor;

    if (isActive) {
      bgColor = const Color(0xFFECFDF5);
      dotColor = const Color(0xFF10B981);
      textColor = const Color(0xFF065F46);
    } else if (isPending) {
      bgColor = const Color(0xFFFFF7ED);
      dotColor = const Color(0xFFF59E0B);
      textColor = const Color(0xFF92400E);
    } else {
      bgColor = const Color(0xFFFEF2F2);
      dotColor = const Color(0xFFEF4444);
      textColor = const Color(0xFF991B1B);
    }

    final label = trimmed.isEmpty
        ? 'Unknown'
        : trimmed[0].toUpperCase() + trimmed.substring(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: context.textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
