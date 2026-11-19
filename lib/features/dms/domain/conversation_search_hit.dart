import 'package:zedu/features/dms/domain/message_plain_text.dart';

/// One message found by the server's search of a single conversation.
class ConversationSearchHit {
  final String messageId;
  final String? threadId;
  final String text;
  final String userName;
  final DateTime? sentAt;

  const ConversationSearchHit({
    required this.messageId,
    required this.text,
    required this.userName,
    this.threadId,
    this.sentAt,
  });

  /// `GET /search/channel/:id` answers with groups, each holding a `user` and
  /// that user's matching `messages`. Flattens them newest first, the same
  /// way Zedu web does.
  static List<ConversationSearchHit> fromResponse(Object? data) {
    final groups = data is List ? data : const <Object?>[];
    final hits = <ConversationSearchHit>[];
    for (final group in groups.whereType<Map<dynamic, dynamic>>()) {
      final user = group['user'];
      final thread = group['thread'];
      final userName = user is Map ? user['user_name']?.toString() : null;
      final messages = group['messages'];
      if (messages is! List) continue;
      for (final message in messages.whereType<Map<dynamic, dynamic>>()) {
        final id = message['message_id']?.toString() ?? '';
        if (id.isEmpty) continue;
        final threadId = message['thread_id']?.toString();
        hits.add(
          ConversationSearchHit(
            messageId: id,
            threadId: threadId != null && threadId.isNotEmpty
                ? threadId
                : (thread is Map ? thread['id']?.toString() : null),
            text: plainText(message['message']),
            userName: userName == null || userName.isEmpty
                ? 'Unknown'
                : userName,
            sentAt: DateTime.tryParse(
              message['timestamp']?.toString() ?? '',
            )?.toLocal(),
          ),
        );
      }
    }
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    hits.sort((a, b) => (b.sentAt ?? epoch).compareTo(a.sentAt ?? epoch));
    return hits;
  }

  /// Message content is HTML. Show what the person actually wrote, so neither
  /// tags nor entities appear in the results.
  static String plainText(Object? content) =>
      htmlMessageToPlainText(content?.toString() ?? '');

  /// "4:05 PM" for today, "Nov 3, 4:05 PM" for earlier days.
  String? get sentAtLabel {
    final at = sentAt;
    if (at == null) return null;
    final hour = at.hour > 12 ? at.hour - 12 : (at.hour == 0 ? 12 : at.hour);
    final minute = at.minute.toString().padLeft(2, '0');
    final period = at.hour >= 12 ? 'PM' : 'AM';
    final time = '$hour:$minute $period';
    final now = DateTime.now();
    if (at.year == now.year && at.month == now.month && at.day == now.day) {
      return time;
    }
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[at.month - 1]} ${at.day}, $time';
  }
}
