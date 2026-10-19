/// Uppercase letters for an avatar, taken from the start of [raw].
///
/// Trims first, so a leading space does not paint a blank circle.
/// An empty or whitespace-only value returns [fallback] instead of throwing.
String avatarInitials(String? raw, {int count = 1, String fallback = '?'}) {
  final trimmed = (raw ?? '').trim();
  if (trimmed.isEmpty || count < 1) return fallback;
  final take = trimmed.length < count ? trimmed.length : count;
  return trimmed.substring(0, take).toUpperCase();
}

/// [avatarInitials] of the first candidate that is not blank.
String avatarInitialsFrom(
  Iterable<String?> candidates, {
  int count = 1,
  String fallback = '?',
}) {
  for (final candidate in candidates) {
    final trimmed = (candidate ?? '').trim();
    if (trimmed.isNotEmpty) {
      return avatarInitials(trimmed, count: count, fallback: fallback);
    }
  }
  return fallback;
}
