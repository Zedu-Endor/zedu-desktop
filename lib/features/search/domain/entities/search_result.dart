/// A single message that matched a search.
class SearchMessage {
  const SearchMessage({
    required this.messageId,
    required this.threadId,
    required this.text,
    required this.timestamp,
  });

  final String messageId;
  final String threadId;
  final String text;
  final String timestamp;
}

/// The author of a search hit.
class SearchUser {
  const SearchUser({
    required this.userId,
    required this.userName,
    required this.avatarUrl,
    required this.defaultAvatarUrl,
    required this.isDeactivated,
  });

  final String userId;
  final String userName;
  final String avatarUrl;
  final String defaultAvatarUrl;
  final bool isDeactivated;
}

/// The channel a search hit was found in.
class SearchChannel {
  const SearchChannel({
    required this.channelId,
    required this.channelName,
    required this.channelType,
  });

  final String channelId;
  final String channelName;
  final String channelType;
}

/// One search hit: an author, a channel and the messages that matched.
class SearchResult {
  const SearchResult({
    required this.user,
    required this.messages,
    required this.channel,
  });

  final SearchUser user;
  final List<SearchMessage> messages;
  final SearchChannel channel;
}
