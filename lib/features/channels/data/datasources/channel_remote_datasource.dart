import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

abstract class ChannelRemoteDataSource {
  Future<List<Channel>> fetchChannels(String orgId);
  Future<Map<String, int>> fetchChannelUnreadCounts(String orgId);
  Future<Channel> createChannel({
    required String name,
    required String description,
    required String orgId,
    required String username,
    required bool isPrivate,
    String? topic,
  });
  Future<void> updateChannelTopicOrDescription({
    required String channelId,
    String? topic,
    String? description,
  });
  Future<void> archiveChannel(String channelId, bool archived);

  /// The organisation's archived channels the user can see.
  Future<List<Channel>> fetchArchivedChannels(String orgId);
  Future<void> leaveChannel(String channelId);
  Future<void> joinChannel(String channelId);
  Future<List<String>> fetchOrganisationMemberIds(String orgId);
  Future<List<String>> fetchChannelMemberIds(String channelId);
  Future<List<DmParticipant>> fetchChannelMembers(String channelId);
  Future<void> addMembersToChannel({
    required String channelId,
    required List<String> userIds,
  });

  /// How many messages one page of a channel's history holds.
  static const messagePageSize = 50;

  /// One page of a channel's messages, newest first. Page 1 is the newest.
  Future<ChannelMessagePage> fetchChannelMessages(
    String channelId, {
    int page = 1,
    int limit = messagePageSize,
  });

  /// Replaces the text of the message with [threadId] in [channelId].
  Future<void> editChannelMessage({
    required String channelId,
    required String threadId,
    required String content,
  });

  /// Deletes the message with [threadId] in [channelId].
  Future<void> deleteChannelMessage({
    required String channelId,
    required String threadId,
  });

  /// Usernames of the users who reacted with [reactionId] on [threadId].
  Future<List<String>> fetchReactionUsers({
    required String reactionId,
    required String threadId,
  });

  /// Adds the current user's [emoji] reaction to [threadId], or removes it
  /// if they have already reacted. Returns whether the user reacted now.
  Future<bool> toggleReaction({
    required String channelId,
    required String threadId,
    required String emoji,
  });

  /// Stars the channel for this user, or unstars it if it is already starred.
  /// Returns whether it is starred now.
  Future<bool> toggleStarChannel({
    required String orgId,
    required String channelId,
  });

  /// Starts an export of the channel's history, or returns the one that is
  /// already running.
  Future<ChannelExport> startExport(String channelId);

  /// The latest export of the channel for this user.
  Future<ChannelExport> fetchExportStatus(String channelId);
}

/// The mock build has no server behind it, and staging rejects its token, so
/// writes fail here instead of sending a request that signs the user out.
const _mockBuildFailure = ApiFailure(
  message: 'Not available in the mock build.',
  kind: ApiFailureKind.client,
);

class ChannelRemoteDataSourceImpl implements ChannelRemoteDataSource {
  final ApiBaseService apiBaseService;
  final AppConfig config;

  /// Page size for the paginated member lists (the backend default is 20).
  static const memberPageSize = 100;

  /// Stops paging a broken or endless member list after this many pages.
  static const maxMemberPages = 50;

  /// Page size for the organisation's channel list (the backend default
  /// is 20).
  static const channelPageSize = 100;

  /// Stops paging a broken or endless channel list after this many pages.
  static const maxChannelPages = 50;

  ChannelRemoteDataSourceImpl({
    required this.apiBaseService,
    required this.config,
  });

  /// Every channel in the organisation. The list is paginated, so each page
  /// is fetched until the last one the server reports, a short page, or the
  /// page cap; the channels loaded so far are kept in that last case.
  @override
  Future<List<Channel>> fetchChannels(String orgId) async {
    if (config.usesMockData) return const [];
    final channels = <Channel>[];
    for (var page = 1; page <= maxChannelPages; page++) {
      final response = await apiBaseService.get<Map<String, dynamic>>(
        path: '/organisations/$orgId/channels',
        queryParameters: {'page': page, 'limit': channelPageSize},
      );
      final data = response.data['data'] as List?;
      if (data == null || data.isEmpty) break;
      channels.addAll(
        data.map((e) => Channel.fromJson(e as Map<String, dynamic>)),
      );

      final pagination = response.data['pagination'];
      final totalPages = pagination is Map ? pagination['total_pages'] : null;
      final isLast = totalPages is int
          ? page >= totalPages
          : data.length < channelPageSize;
      if (isLast) break;
    }
    // The browse-all endpoint always returns unread_count 0. The
    // user-channels endpoint fills it, so merge those counts in. A failure
    // there must not fail the whole list: the title just counts DMs then.
    Map<String, int> unreadCounts = const {};
    try {
      unreadCounts = await fetchChannelUnreadCounts(orgId);
    } catch (_) {
      return channels;
    }
    if (unreadCounts.isEmpty) return channels;
    return [
      for (final channel in channels)
        unreadCounts.containsKey(channel.id)
            ? channel.copyWith(unreadCount: unreadCounts[channel.id]!)
            : channel,
    ];
  }

  @override
  Future<Map<String, int>> fetchChannelUnreadCounts(String orgId) async {
    if (config.usesMockData) return const {};
    final response = await apiBaseService.get<Map<String, dynamic>>(
      path: '/organisations/$orgId/user-channels',
    );
    final data = response.data['data'] as List?;
    if (data == null) return const {};
    final counts = <String, int>{};
    for (final entry in data) {
      final channel = Channel.fromJson(entry as Map<String, dynamic>);
      if (channel.id.isEmpty) continue;
      counts[channel.id] = channel.unreadCount;
    }
    return counts;
  }

  @override
  Future<bool> toggleStarChannel({
    required String orgId,
    required String channelId,
  }) async {
    if (config.usesMockData) throw _mockBuildFailure;
    final response = await apiBaseService.post<Map<String, dynamic>>(
      path: '/organisations/$orgId/channels/$channelId/star',
    );
    final data = response.data['data'] as Map<String, dynamic>?;
    final isStarred = data?['is_starred'] as bool?;
    if (isStarred == null) {
      throw Exception('No star state returned from toggle star');
    }
    return isStarred;
  }

  @override
  Future<Channel> createChannel({
    required String name,
    required String description,
    required String orgId,
    required String username,
    required bool isPrivate,
    String? topic,
  }) async {
    if (config.usesMockData) throw _mockBuildFailure;
    final body = {
      'name': name,
      'description': description,
      'organisation_id': orgId,
      'username': username,
      'is_private': isPrivate,
      'topic': ?topic,
    };
    final response = await apiBaseService.post<Map<String, dynamic>>(
      path: '/channels',
      data: body,
    );
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('No data returned from create channel');
    return Channel.fromJson(data);
  }

  @override
  Future<void> updateChannelTopicOrDescription({
    required String channelId,
    String? topic,
    String? description,
  }) async {
    if (config.usesMockData) throw _mockBuildFailure;
    final data = <String, dynamic>{};
    if (topic != null) data['topic'] = topic;
    if (description != null) data['description'] = description;

    // The backend saves topic/description edits on PATCH /channels/{id}, the
    // route the web app uses; a PUT to '/channels/{id}/' never saved (#1432).
    await apiBaseService.patch<Map<String, dynamic>>(
      path: '/channels/$channelId',
      data: data,
    );
  }

  @override
  Future<void> archiveChannel(String channelId, bool archived) async {
    if (config.usesMockData) throw _mockBuildFailure;
    await apiBaseService.put<Map<String, dynamic>>(
      path: '/channels/$channelId/archive',
      data: {'archived': archived},
    );
  }

  @override
  Future<List<Channel>> fetchArchivedChannels(String orgId) async {
    if (config.usesMockData) return const [];
    final response = await apiBaseService.get<Map<String, dynamic>>(
      path: '/organisations/$orgId/channels/archived',
    );
    final data = response.data['data'] as List?;
    if (data == null) return [];
    return data
        .map((e) => Channel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> leaveChannel(String channelId) async {
    if (config.usesMockData) throw _mockBuildFailure;
    await apiBaseService.post<Map<String, dynamic>>(
      path: '/channels/$channelId/leave',
    );
  }

  @override
  Future<void> joinChannel(String channelId) async {
    if (config.usesMockData) throw _mockBuildFailure;
    await apiBaseService.post<Map<String, dynamic>>(
      path: '/channels/$channelId/join',
      data: const <String, dynamic>{},
    );
  }

  @override
  Future<ChannelExport> startExport(String channelId) async {
    if (config.usesMockData) throw _mockBuildFailure;
    final response = await apiBaseService.post<Map<String, dynamic>>(
      path: '/channels/$channelId/export',
    );
    return _exportFrom(response.data);
  }

  @override
  Future<ChannelExport> fetchExportStatus(String channelId) async {
    if (config.usesMockData) throw _mockBuildFailure;
    final response = await apiBaseService.get<Map<String, dynamic>>(
      path: '/channels/$channelId/export/status',
    );
    return _exportFrom(response.data);
  }

  static ChannelExport _exportFrom(Map<String, dynamic>? body) {
    final data = body?['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('No export returned for the channel');
    }
    return ChannelExport.fromJson(data);
  }

  @override
  Future<List<String>> fetchOrganisationMemberIds(String orgId) {
    if (config.usesMockData) return Future.value(const []);
    // People only: this endpoint leaves bots out unless include_bots=true.
    return _fetchAllMemberIds('/organisations/$orgId/users');
  }

  @override
  Future<List<String>> fetchChannelMemberIds(String channelId) {
    if (config.usesMockData) return Future.value(const []);
    return _fetchAllMemberIds('/channels/$channelId/users');
  }

  @override
  Future<List<DmParticipant>> fetchChannelMembers(String channelId) async {
    if (config.usesMockData) return const [];
    final members = await _fetchAllMembers('/channels/$channelId/users');
    return [
      for (final member in members)
        if ((member['id'] as String? ?? '').isNotEmpty &&
            _memberField(member, 'username').isNotEmpty)
          DmParticipant(
            userId: member['id'] as String,
            username: _memberField(member, 'username'),
            email: member['email'] as String? ?? '',
            avatarUrl: _memberField(member, 'avatar_url').isEmpty
                ? null
                : _memberField(member, 'avatar_url'),
          ),
    ];
  }

  @override
  Future<void> addMembersToChannel({
    required String channelId,
    required List<String> userIds,
  }) async {
    if (config.usesMockData) throw _mockBuildFailure;
    await apiBaseService.post<Map<String, dynamic>>(
      path: '/channels/add-multiple',
      data: {'channel_id': channelId, 'user_ids': userIds},
    );
  }

  @override
  Future<void> editChannelMessage({
    required String channelId,
    required String threadId,
    required String content,
  }) async {
    if (config.usesMockData) throw _mockBuildFailure;
    await apiBaseService.put<Map<String, dynamic>>(
      path: '/threads/$threadId/channels/$channelId',
      data: {'content': content},
    );
  }

  @override
  Future<void> deleteChannelMessage({
    required String channelId,
    required String threadId,
  }) async {
    if (config.usesMockData) throw _mockBuildFailure;
    await apiBaseService.delete<Map<String, dynamic>>(
      path: '/threads/$threadId/channels/$channelId',
    );
  }

  @override
  Future<ChannelMessagePage> fetchChannelMessages(
    String channelId, {
    int page = 1,
    int limit = ChannelRemoteDataSource.messagePageSize,
  }) async {
    if (config.usesMockData) {
      return const ChannelMessagePage(messages: [], hasMore: false);
    }
    final response = await apiBaseService.get<Map<String, dynamic>>(
      path: '/threads/channels/$channelId',
      queryParameters: {'page': page, 'limit': limit},
    );
    final data = response.data['data'];
    if (data == null) {
      return const ChannelMessagePage(messages: [], hasMore: false);
    }
    // A wrong shape throws, so the list shows its retry state.
    final messages = (data as List)
        .cast<Map<String, dynamic>>()
        .map(ChannelMessage.fromJson)
        .toList();
    return ChannelMessagePage(
      messages: messages,
      hasMore: _hasMorePages(
        response.data['pagination'],
        page: page,
        limit: limit,
        received: messages.length,
      ),
    );
  }

  /// Reads the response's pagination block. Without a usable one, a full page
  /// means there may be another, and the next request settles it: an empty
  /// page ends the list.
  bool _hasMorePages(
    Object? pagination, {
    required int page,
    required int limit,
    required int received,
  }) {
    if (pagination is Map) {
      final hasMore =
          pagination['has_more'] ??
          pagination['has_next'] ??
          pagination['hasNext'];
      if (hasMore is bool) return hasMore;
      final totalPages = int.tryParse(
        '${pagination['total_pages'] ?? pagination['total_pages_count'] ?? pagination['totalPages']}',
      );
      if (totalPages != null) return page < totalPages;
    }
    return received >= limit;
  }

  @override
  Future<List<String>> fetchReactionUsers({
    required String reactionId,
    required String threadId,
  }) async {
    if (config.usesMockData) return const [];
    final response = await apiBaseService.get<Map<String, dynamic>>(
      path: '/reactions/$reactionId/thread/$threadId',
    );
    final data = response.data['data'] as Map<String, dynamic>?;
    final usernames = data?['usernames'] as List?;
    if (usernames == null) return [];
    return [
      // The backend sends either plain username strings or user objects.
      for (final entry in usernames)
        if (entry is String && entry.trim().isNotEmpty)
          entry.trim()
        else if (entry is Map<String, dynamic>)
          ..._usernameFromUserObject(entry),
    ];
  }

  @override
  Future<bool> toggleReaction({
    required String channelId,
    required String threadId,
    required String emoji,
  }) async {
    if (config.usesMockData) throw _mockBuildFailure;
    final response = await apiBaseService.post<Map<String, dynamic>>(
      path: '/reactions/$channelId',
      data: {'reaction': emoji, 'thread_id': threadId, 'type': 'thread'},
    );
    final data = response.data['data'];
    // Toggle semantics: the user is removed when data comes back null/empty.
    if (data is Map<String, dynamic>) {
      final reaction = data['reaction']?.toString() ?? '';
      if (reaction == emoji) return true;
    }
    return false;
  }

  // The channel users route nests username and avatar_url under profile.
  String _memberField(Map<String, dynamic> member, String field) {
    final profile = member['profile'];
    final nested = profile is Map<String, dynamic> ? profile[field] : null;
    if (nested is String && nested.isNotEmpty) return nested;
    final topLevel = member[field];
    return topLevel is String ? topLevel : '';
  }

  List<String> _usernameFromUserObject(Map<String, dynamic> user) {
    final username = _memberField(user, 'username').trim();
    return username.isEmpty ? const [] : [username];
  }

  Future<List<String>> _fetchAllMemberIds(String path) async {
    final members = await _fetchAllMembers(path);
    return [
      for (final member in members)
        if ((member['id'] as String? ?? '').isNotEmpty) member['id'] as String,
    ];
  }

  Future<List<Map<String, dynamic>>> _fetchAllMembers(String path) async {
    final members = <Map<String, dynamic>>[];
    for (var page = 1; page <= maxMemberPages; page++) {
      final response = await apiBaseService.get<Map<String, dynamic>>(
        path: path,
        queryParameters: {'page': page, 'limit': memberPageSize},
      );
      final data = response.data['data'] as List?;
      if (data == null || data.isEmpty) return members;
      members.addAll(data.cast<Map<String, dynamic>>());
      if (data.length < memberPageSize) return members;
    }
    // Every page was full, so the list may go on. Fail rather than act on
    // part of it.
    throw ApiFailure(
      message: 'Too many members to load. Please try again later.',
      path: path,
    );
  }
}
