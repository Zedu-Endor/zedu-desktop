import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Workspace-wide message search (#2825), through the endpoint the web app
/// uses: `GET /search/organisation/{orgId}?query=…&sortBy=…`.
class MessageSearchService {
  MessageSearchService(this._apiClient);

  final ApiBaseService _apiClient;

  /// Searches every channel and conversation in [orgId] for [query], which
  /// already carries the filter tokens (see [buildMessageSearchQuery]).
  /// Newest first. A 404 means nothing matched.
  Future<List<SearchResultModel>> search({
    required String orgId,
    required String query,
  }) async {
    if (orgId.isEmpty || query.trim().isEmpty) return const [];
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        path: '/search/organisation/$orgId',
        queryParameters: {'query': query, 'sortBy': 'newest'},
      );
      return flattenMessageSearchResults(response.data['data']);
    } on ApiFailure catch (failure) {
      if (failure.statusCode == 404) return const [];
      rethrow;
    }
  }
}

/// The backend answers with groups, one per sender and channel, each holding
/// that sender's matching messages:
///
/// ```json
/// [{"user": {"user_name": "Ada", "avatar_url": "…"},
///   "channel": {"channel_id": "c1", "channel_name": "general"},
///   "messages": [{"message_id": "m1", "message": "<p>hi</p>", "timestamp": "…"}]}]
/// ```
///
/// This turns them into one [SearchResultModel] per message, newest first,
/// with any HTML in the message reduced to its text.
List<SearchResultModel> flattenMessageSearchResults(Object? raw) {
  final groups = raw is List ? raw : const <dynamic>[];
  final results = <SearchResultModel>[];
  for (final group in groups.whereType<Map<dynamic, dynamic>>()) {
    final user = group['user'] is Map
        ? group['user'] as Map
        : const <dynamic, dynamic>{};
    final channel = group['channel'] is Map
        ? group['channel'] as Map
        : const <dynamic, dynamic>{};
    final messages = group['messages'] is List
        ? group['messages'] as List
        : const <dynamic>[];
    for (final message in messages.whereType<Map<dynamic, dynamic>>()) {
      final id = message['message_id']?.toString() ?? '';
      if (id.isEmpty) continue;
      results.add(
        SearchResultModel(
          id: id,
          content: messageSearchPlainText(message['message']?.toString() ?? ''),
          channelId: channel['channel_id']?.toString() ?? '',
          channelName: channel['channel_name']?.toString() ?? '',
          senderName: user['user_name']?.toString() ?? '',
          senderAvatarUrl: _nonEmpty(
            user['avatar_url'] ?? user['default_avatar_url'],
          ),
          createdAt: DateTime.tryParse(message['timestamp']?.toString() ?? ''),
        ),
      );
    }
  }
  results.sort((a, b) {
    final aTime = a.createdAt, bTime = b.createdAt;
    if (aTime == null && bTime == null) return 0;
    if (aTime == null) return 1;
    if (bTime == null) return -1;
    return bTime.compareTo(aTime);
  });
  return results;
}

String? _nonEmpty(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

/// Message bodies are HTML. Search shows what the person wrote: tags become
/// spaces, the common entities are decoded and runs of space collapse.
String messageSearchPlainText(String html) {
  final text = html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&amp;', '&');
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}
