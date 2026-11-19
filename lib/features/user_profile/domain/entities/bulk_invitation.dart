/// Parsed addresses preserve input order and are normalized for deduplication.
class BulkInvitation {
  static List<String> addresses(String input) => input
      .split(RegExp(r'[,;\s]+'))
      .map((email) => email.trim().toLowerCase())
      .where((email) => email.isNotEmpty)
      .toSet()
      .toList();

  static bool valid(String email) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
}
