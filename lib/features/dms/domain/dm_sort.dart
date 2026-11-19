import 'dm_conversation.dart';

/// Sort order for the Desktop DM conversation list.
enum DmSort {
  recentActivity('Recent activity'),
  alphabetical('A–Z');

  const DmSort(this.label);

  /// Shown in the sort menu.
  final String label;

  /// Orders two conversations for this sort. Pinned conversations always come
  /// first so they stay at the top in both modes; the chosen order decides
  /// within each group.
  int compare(
    DmConversation a,
    DmConversation b, {
    required bool aPinned,
    required bool bPinned,
  }) {
    if (aPinned != bPinned) return aPinned ? -1 : 1;
    final primary = switch (this) {
      DmSort.alphabetical => _byName(a, b),
      DmSort.recentActivity => _byRecentActivity(a, b),
    };
    if (primary != 0) return primary;
    // Same name, or the same timestamp: keep the list stable.
    return _byRecentActivity(a, b);
  }

  static int _byName(DmConversation a, DmConversation b) =>
      a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());

  static int _byRecentActivity(DmConversation a, DmConversation b) =>
      b.lastActivityAt.compareTo(a.lastActivityAt);
}
