import 'package:zedu/core/core.dart';

class ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final AppPalette colors;
  final bool isActive;

  const ToolbarButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.colors,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      // The toolbar row sits at the bottom of the composer, so a below
      // tooltip lands on the window edge where it is clipped.
      preferBelow: false,
      verticalOffset: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          decoration: BoxDecoration(
            color: isActive
                ? colors.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isActive
                ? colors.primary
                : colors.textPrimary.withValues(alpha: 0.75),
          ),
        ),
      ),
    );
  }
}
