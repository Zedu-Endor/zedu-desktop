import 'package:zedu/core/core.dart';

/// The first character of [name] for an avatar, upper-cased, or [fallback]
/// when there is none.
///
/// It takes a whole character (a grapheme), so a name that starts with an
/// emoji, a flag or another non-BMP character isn't cut in half the way
/// `name[0]` cuts it.
String avatarInitial(String? name, {String fallback = '?'}) {
  final trimmed = name?.trim() ?? '';
  if (trimmed.isEmpty) return fallback;
  return trimmed.characters.first.toUpperCase();
}

/// The initials of [name] for an avatar, upper-cased, or [fallback]
/// when there is none.
///
/// It takes whole characters (graphemes), so a name that starts with or contains
/// an emoji, a flag or another non-BMP character isn't cut in half.
/// For multi-word names, it takes the first character of the first and last word.
/// For single-word names, it takes the first character.
String avatarInitials(String? name, {String fallback = '?'}) {
  final trimmed = name?.trim() ?? '';
  if (trimmed.isEmpty) return fallback;
  final parts = trimmed
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return fallback;
  if (parts.length == 1) {
    return parts.first.characters.first.toUpperCase();
  }
  return '${parts.first.characters.first}${parts.last.characters.first}'
      .toUpperCase();
}
