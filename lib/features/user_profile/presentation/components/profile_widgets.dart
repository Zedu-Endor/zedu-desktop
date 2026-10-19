import 'dart:io';

import 'package:zedu/core/core.dart';

ImageProvider<Object>? profileAvatarImageProvider(String? avatarUrl) {
  if (avatarUrl == null || avatarUrl.isEmpty) return null;
  if (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://')) {
    return NetworkImage(avatarUrl);
  }
  return FileImage(File(avatarUrl));
}

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
    this.size = 32,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: size * 0.56, color: const Color(0xFF374151)),
      ),
    );
  }
}

class ProfileStatusPill extends StatelessWidget {
  const ProfileStatusPill({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isActive = status.toLowerCase() == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF10B981)
                  : const Color(0xFFEF4444),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status[0].toUpperCase() + status.substring(1),
            style: context.textTheme.labelSmall?.copyWith(
              color: isActive
                  ? const Color(0xFF065F46)
                  : const Color(0xFF991B1B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
