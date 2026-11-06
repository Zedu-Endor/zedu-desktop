import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

final savedRepositoryProvider = Provider<SavedRepository>((ref) {
  return SavedRepository(locator<ApiBaseService>());
});

/// The saved-message and reminder endpoints the web app already uses.
///
/// Reminders are set on the server, not on the device: the server stores the
/// time and queues the job that sends the notification, so a reminder set here
/// also shows on web and mobile and still fires with the desktop app closed.
class SavedRepository {
  SavedRepository(this._apiClient);

  final ApiBaseService _apiClient;

  Future<List<SavedMessage>> list({required String orgId}) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      path: '/organisations/$orgId/saved/message',
    );

    final raw = response.data['data'];
    return (raw is List ? raw : const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(SavedMessage.fromJson)
        .where((item) => item.id.isNotEmpty)
        .toList();
  }

  /// Saves a message. A whole thread and a reply inside one take different
  /// endpoints, and the reply also sends its own id.
  Future<void> save({
    required String orgId,
    required SavedTarget target,
  }) async {
    final messageId = target.messageId;
    if (messageId == null) {
      await _apiClient.post<Map<String, dynamic>>(
        path: '/organisations/$orgId/thread/save',
        data: {'channels_id': target.channelId, 'thread_id': target.threadId},
      );
      return;
    }

    await _apiClient.post<Map<String, dynamic>>(
      path: '/organisations/$orgId/message/save',
      data: {
        'channels_id': target.channelId,
        'thread_id': target.threadId,
        'message_id': messageId,
      },
    );
  }

  /// Removes a saved item by **the saved item's own id**. The thread id
  /// answers 404 here, which is why the list has to be loaded before a
  /// message can be unsaved.
  Future<void> remove({
    required String orgId,
    required String savedMessageId,
  }) async {
    await _apiClient.delete<Map<String, dynamic>>(
      path: '/organisations/$orgId/saved/message/$savedMessageId',
    );
  }

  /// Sets or changes the reminder on a saved message.
  ///
  /// [remindAt] is whatever local time the user picked; it is sent as UTC
  /// because the server stores and queues in UTC. `type` follows the server's
  /// own request model, which names the two kinds `thread` and `message`.
  Future<void> setReminder({
    required String orgId,
    required SavedTarget target,
    required DateTime remindAt,
  }) async {
    final messageId = target.messageId;
    await _apiClient.put<Map<String, dynamic>>(
      path: '/organisations/$orgId/set-remainder',
      data: {
        'type': target.kind.wire,
        'channels_id': target.channelId,
        'thread_id': target.threadId,
        'message_id': ?messageId,
        'remainder_at': remindAt.toUtc().toIso8601String(),
      },
    );
  }
}
