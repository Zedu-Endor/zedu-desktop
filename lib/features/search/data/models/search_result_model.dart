/// A single message returned by the backend search endpoint.
class SearchMessageModel {
  const SearchMessageModel({
    required this.messageId,
    required this.threadId,
    required this.text,
    required this.timestamp,
  });

  factory SearchMessageModel.fromJson(Map<String, dynamic> json) {
    return SearchMessageModel(
      messageId: json['message_id'] as String? ?? '',
      threadId: json['thread_id'] as String? ?? '',
      text: json['message'] as String? ?? '',
      timestamp: json['timestamp'] as String? ?? '',
    );
  }

  final String messageId;
  final String threadId;
  final String text;
  final String timestamp;

  Map<String, dynamic> toJson() => {
    'message_id': messageId,
    'thread_id': threadId,
    'message': text,
    'timestamp': timestamp,
  };
}

/// The author of a search hit.
class SearchUserModel {
  const SearchUserModel({
    required this.userId,
    required this.userName,
    required this.avatarUrl,
    required this.defaultAvatarUrl,
    required this.isDeactivated,
  });

  factory SearchUserModel.fromJson(Map<String, dynamic> json) {
    return SearchUserModel(
      userId: json['user_id'] as String? ?? '',
      userName: json['user_name'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? '',
      defaultAvatarUrl: json['default_avatar_url'] as String? ?? '',
      isDeactivated: json['is_deactivated'] as bool? ?? false,
    );
  }

  final String userId;
  final String userName;
  final String avatarUrl;
  final String defaultAvatarUrl;
  final bool isDeactivated;

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'user_name': userName,
    'avatar_url': avatarUrl,
    'default_avatar_url': defaultAvatarUrl,
    'is_deactivated': isDeactivated,
  };
}

/// The channel a search hit was found in.
class SearchChannelModel {
  const SearchChannelModel({
    required this.channelId,
    required this.channelName,
    required this.channelType,
  });

  factory SearchChannelModel.fromJson(Map<String, dynamic> json) {
    return SearchChannelModel(
      channelId: json['channel_id'] as String? ?? '',
      channelName: json['channel_name'] as String? ?? '',
      channelType: json['channel_type'] as String? ?? '',
    );
  }

  final String channelId;
  final String channelName;
  final String channelType;

  Map<String, dynamic> toJson() => {
    'channel_id': channelId,
    'channel_name': channelName,
    'channel_type': channelType,
  };
}

/// One search hit: an author, a channel, and the messages that matched.
class SearchResultModel {
  const SearchResultModel({
    required this.user,
    required this.messages,
    required this.channel,
  });

  factory SearchResultModel.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'];
    final messages = rawMessages is List
        ? rawMessages
              .whereType<Map<String, dynamic>>()
              .map(SearchMessageModel.fromJson)
              .toList()
        : const <SearchMessageModel>[];

    final rawUser = json['user'];
    final rawChannel = json['channel'];

    return SearchResultModel(
      user: rawUser is Map<String, dynamic>
          ? SearchUserModel.fromJson(rawUser)
          : const SearchUserModel(
              userId: '',
              userName: '',
              avatarUrl: '',
              defaultAvatarUrl: '',
              isDeactivated: false,
            ),
      messages: messages,
      channel: rawChannel is Map<String, dynamic>
          ? SearchChannelModel.fromJson(rawChannel)
          : const SearchChannelModel(
              channelId: '',
              channelName: '',
              channelType: '',
            ),
    );
  }

  final SearchUserModel user;
  final List<SearchMessageModel> messages;
  final SearchChannelModel channel;

  Map<String, dynamic> toJson() => {
    'user': user.toJson(),
    'messages': messages.map((m) => m.toJson()).toList(),
    'channel': channel.toJson(),
  };
}
