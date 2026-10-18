/// Human-readable member count, e.g. `1 member`, `12 members`.
///
/// Used wherever a channel or workspace member count is shown so the noun
/// matches the count.
String formatMemberCount(int count) {
  final noun = count == 1 ? 'member' : 'members';
  return '$count $noun';
}
