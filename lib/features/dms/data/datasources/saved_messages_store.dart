import 'dart:async';
import 'dart:convert';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// A message someone saved so they can find it again later.
///
/// The text is a snapshot taken when the message was saved, because the
/// original may be edited or deleted afterwards and the Saved items view still
/// needs to show what was kept.
class SavedMessage {
  const SavedMessage({
    required this.messageId,
    required this.channelId,
    required this.conversationName,
    required this.senderName,
    required this.content,
    required this.messageCreatedAt,
    required this.savedAt,
  });

  final String messageId;
  final String channelId;
  final String conversationName;
  final String senderName;
  final String content;
  final DateTime messageCreatedAt;
  final DateTime savedAt;

  String get id => '$channelId:$messageId';

  Map<String, dynamic> toJson() => {
    'messageId': messageId,
    'channelId': channelId,
    'conversationName': conversationName,
    'senderName': senderName,
    'content': content,
    'messageCreatedAt': messageCreatedAt.millisecondsSinceEpoch,
    'savedAt': savedAt.millisecondsSinceEpoch,
  };

  factory SavedMessage.fromJson(Map<String, dynamic> json) => SavedMessage(
    messageId: json['messageId'] as String? ?? '',
    channelId: json['channelId'] as String? ?? '',
    conversationName: json['conversationName'] as String? ?? '',
    senderName: json['senderName'] as String? ?? '',
    content: json['content'] as String? ?? '',
    messageCreatedAt: DateTime.fromMillisecondsSinceEpoch(
      json['messageCreatedAt'] as int? ?? 0,
    ),
    savedAt: DateTime.fromMillisecondsSinceEpoch(json['savedAt'] as int? ?? 0),
  );
}

/// Remembers on this computer which messages a person saved, so Saved items
/// survives an app restart. Kept per signed-in user, so another account on the
/// same machine starts with its own list.
///
/// The backend has no saved-message field yet, hence local storage. Saving
/// never writes to the conversation itself.
class SavedMessagesStore extends ChangeNotifier {
  SavedMessagesStore(this._storage, {required String userId})
    : _storageKey = userId.isEmpty ? null : 'saved_messages_$userId';

  final SecureStorageService? _storage;
  final String? _storageKey;

  final List<SavedMessage> _items = [];
  bool _loaded = false;
  bool _disposed = false;

  /// Saved messages, most recently saved first.
  List<SavedMessage> get items => List.unmodifiable(_items);

  bool get isLoaded => _loaded;

  bool isSaved(String channelId, String messageId) => _items.any(
    (item) => item.channelId == channelId && item.messageId == messageId,
  );

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final storage = _storage;
    final key = _storageKey;
    if (storage != null && key != null) {
      try {
        final raw = await storage.readData(key);
        final decoded = raw == null || raw.isEmpty ? null : jsonDecode(raw);
        if (decoded is List) {
          for (final entry in decoded.whereType<Map<String, dynamic>>()) {
            final item = SavedMessage.fromJson(entry);
            if (item.messageId.isNotEmpty && item.channelId.isNotEmpty) {
              _items.add(item);
            }
          }
        }
      } catch (_) {
        // A corrupt or unreadable list starts empty; saving writes it again.
      }
    }
    _sort();
    _notify();
  }

  Future<void> toggle(SavedMessage item) async {
    if (isSaved(item.channelId, item.messageId)) {
      await remove(item.id);
    } else {
      await save(item);
    }
  }

  Future<void> save(SavedMessage item) async {
    if (item.messageId.isEmpty || item.channelId.isEmpty) return;
    if (isSaved(item.channelId, item.messageId)) return;
    _items.insert(0, item);
    _notify();
    await _persist();
  }

  Future<void> remove(String id) async {
    final before = _items.length;
    _items.removeWhere((item) => item.id == id);
    if (_items.length == before) return;
    _notify();
    await _persist();
  }

  void _sort() => _items.sort((a, b) => b.savedAt.compareTo(a.savedAt));

  Future<void> _persist() async {
    final storage = _storage;
    final key = _storageKey;
    if (storage == null || key == null) return;
    try {
      await storage.writeData(
        key,
        jsonEncode(_items.map((item) => item.toJson()).toList()),
      );
    } catch (_) {
      // Storage failure keeps the in-memory list usable for this session.
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

final savedMessagesStoreProvider = ChangeNotifierProvider<SavedMessagesStore>((
  ref,
) {
  // Rebuilding on a user change also drops the previous in-memory list.
  final userId = dmPreferencesUserId(ref) ?? '';
  final store = SavedMessagesStore(
    locator.isRegistered<SecureStorageService>()
        ? locator<SecureStorageService>()
        : null,
    userId: userId,
  );
  unawaited(store.load());
  return store;
});
