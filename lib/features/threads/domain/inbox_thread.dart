/// A discussion returned by the organisation-wide Threads endpoint.
class InboxThread {
  const InboxThread({
    required this.id,
    required this.channelId,
    required this.channelName,
    required this.messages,
  });
  final String id;
  final String channelId;
  final String channelName;
  final List<InboxThreadMessage> messages;

  factory InboxThread.fromJson(Map<String, dynamic> json) {
    final raw = json['thread_messages'];
    if (raw is! List || raw.isEmpty) {
      throw const FormatException('Missing thread messages');
    }
    final messages = raw
        .map(
          (row) => InboxThreadMessage.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
    final id = (json['thread_id'] ?? messages.first.threadId).toString();
    final channel = messages.first.channelId;
    if (id.isEmpty || channel.isEmpty) {
      throw const FormatException('Missing thread identifiers');
    }
    return InboxThread(
      id: id,
      channelId: channel,
      channelName: (json['channel_name'] ?? '').toString(),
      messages: List.unmodifiable(messages),
    );
  }
}

class InboxThreadMessage {
  const InboxThreadMessage({
    required this.threadId,
    required this.channelId,
    required this.author,
    required this.content,
  });
  final String threadId;
  final String channelId;
  final String author;
  final String content;
  factory InboxThreadMessage.fromJson(Map<String, dynamic> json) =>
      InboxThreadMessage(
        threadId: (json['thread_id'] ?? '').toString(),
        channelId: (json['channels_id'] ?? '').toString(),
        author: (json['username'] ?? json['full_name'] ?? 'Someone').toString(),
        content: (json['message'] ?? json['content'] ?? '').toString(),
      );
}

class ThreadsPage {
  const ThreadsPage({
    required this.threads,
    required this.unseenCount,
    required this.hasMore,
  });
  final List<InboxThread> threads;
  final int unseenCount;
  final bool hasMore;
  factory ThreadsPage.fromJson(Map<String, dynamic> json, int requestedPage) {
    final payload = json['data'];
    final Object? rows = payload is List
        ? payload
        : payload is Map
        ? payload['threads']
        : null;
    if (rows is! List) {
      throw const FormatException('Invalid organisation threads response');
    }
    final threads = rows
        .map(
          (row) => InboxThread.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
    final pagination = json['pagination'];
    int integer(Object? value) =>
        value is num ? value.toInt() : int.tryParse('$value') ?? 0;
    final totalPages = pagination is Map
        ? integer(pagination['total_pages_count'])
        : 0;
    return ThreadsPage(
      threads: List.unmodifiable(threads),
      unseenCount: payload is Map
          ? integer(payload['unseen_thread_count']).clamp(0, 2147483647)
          : 0,
      hasMore:
          threads.isNotEmpty &&
          (totalPages > 0 ? requestedPage < totalPages : threads.length >= 50),
    );
  }
}
