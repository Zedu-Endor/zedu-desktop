/// When a searched message was sent (#2825).
enum MessageSearchDate {
  anyTime('Any time'),
  today('Today'),
  yesterday('Yesterday'),
  last7Days('Last 7 days'),
  last30Days('Last 30 days'),
  last12Months('Last 12 months');

  const MessageSearchDate(this.label);

  final String label;
}

/// The filters on a workspace message search (#2825): who sent it ([from]),
/// where it was sent ([channel]) and when ([date]).
///
/// The backend reads them as tokens in the query, the same ones the web app
/// sends: `from:<name>`, `in:<channel>`, `on:<date>`, `after:<date>` and
/// `before:<date>`.
class MessageSearchFilters {
  const MessageSearchFilters({
    this.from,
    this.channel,
    this.date = MessageSearchDate.anyTime,
  });

  /// The sender's display name, or null for anyone.
  final String? from;

  /// The channel's name, or null for every channel.
  final String? channel;

  final MessageSearchDate date;

  static const none = MessageSearchFilters();

  bool get hasFrom => (from ?? '').trim().isNotEmpty;
  bool get hasChannel => (channel ?? '').trim().isNotEmpty;
  bool get hasDate => date != MessageSearchDate.anyTime;

  /// How many filters are on, for the "Clear filters" control.
  int get activeCount =>
      (hasFrom ? 1 : 0) + (hasChannel ? 1 : 0) + (hasDate ? 1 : 0);

  MessageSearchFilters withFrom(String? value) =>
      MessageSearchFilters(from: value, channel: channel, date: date);

  MessageSearchFilters withChannel(String? value) =>
      MessageSearchFilters(from: from, channel: value, date: date);

  MessageSearchFilters withDate(MessageSearchDate value) =>
      MessageSearchFilters(from: from, channel: channel, date: value);

  @override
  bool operator ==(Object other) =>
      other is MessageSearchFilters &&
      other.from == from &&
      other.channel == channel &&
      other.date == date;

  @override
  int get hashCode => Object.hash(from, channel, date);
}

/// A value as one query token: quoted when it holds a space, with any quote
/// inside escaped, so `Ada Lovelace` stays one name.
String messageSearchToken(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  final escaped = trimmed.replaceAll('"', r'\"');
  return RegExp(r'\s').hasMatch(trimmed) ? '"$escaped"' : escaped;
}

String _day(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

/// The query the backend searches for: the typed words, lower-cased (the
/// match is case-insensitive), then a token for each filter that is on.
///
/// [now] is the local time the date filters count back from.
String buildMessageSearchQuery(
  String text,
  MessageSearchFilters filters, {
  required DateTime now,
}) {
  final parts = <String>[];
  final words = text.trim().toLowerCase();
  if (words.isNotEmpty) parts.add(words);

  if (filters.hasFrom) parts.add('from:${messageSearchToken(filters.from!)}');
  if (filters.hasChannel) {
    parts.add('in:${messageSearchToken(filters.channel!)}');
  }

  final today = DateTime(now.year, now.month, now.day);
  String since(DateTime start) => 'after:${_day(start)} before:${_day(today)}';
  switch (filters.date) {
    case MessageSearchDate.anyTime:
      break;
    case MessageSearchDate.today:
      parts.add('on:${_day(today)}');
    case MessageSearchDate.yesterday:
      parts.add('on:${_day(today.subtract(const Duration(days: 1)))}');
    case MessageSearchDate.last7Days:
      parts.add(since(today.subtract(const Duration(days: 7))));
    case MessageSearchDate.last30Days:
      parts.add(since(today.subtract(const Duration(days: 30))));
    case MessageSearchDate.last12Months:
      parts.add(since(DateTime(today.year - 1, today.month, today.day)));
  }

  return parts.join(' ');
}
