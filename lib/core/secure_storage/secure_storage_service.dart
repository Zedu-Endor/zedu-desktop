import 'package:zedu/core/core.dart';

class SecureStorageService {
  SecureStorageService() : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  // Logout waits for in-flight writes before deleting a user's saved drafts.
  final Map<String, Set<Future<void>>> _pendingWrites = {};
  // Prevents a late composer save from restoring data after logout.
  final Set<String> _blockedPrefixes = {};

  static const _accessTokenKey = 'access_token';

  /// Token kept for this run only, never written to disk.
  String? _sessionToken;

  /// With [persist] false ("Remember me" unticked) the token lives in memory
  /// only, so the next launch starts signed out.
  Future<void> saveAccessToken(String token, {bool persist = true}) async {
    if (persist) {
      _sessionToken = null;
      await _storage.write(key: _accessTokenKey, value: token);
    } else {
      _sessionToken = token;
      await _storage.delete(key: _accessTokenKey);
    }
  }

  Future<String?> getAccessToken() async =>
      _sessionToken ?? await _storage.read(key: _accessTokenKey);

  Future<void> deleteAccessToken() async {
    _sessionToken = null;
    await _storage.delete(key: _accessTokenKey);
  }

  Future<void> writeData(String key, String value) {
    if (_blockedPrefixes.any(key.startsWith)) return Future.value();

    final pending = _pendingWrites.putIfAbsent(key, () => {});
    late final Future<void> write;
    write = _storage.write(key: key, value: value).whenComplete(() {
      pending.remove(write);
      if (pending.isEmpty) _pendingWrites.remove(key);
    });
    pending.add(write);
    return write;
  }

  Future<String?> readData(String key) => _storage.read(key: key);

  Future<void> deleteValue(String key) => _storage.delete(key: key);

  /// Blocks new writes, drains pending writes, then deletes all matching keys.
  Future<void> deleteValuesWithPrefix(String prefix) async {
    _blockedPrefixes.add(prefix);
    final pendingWrites = _pendingWrites.entries
        .where((entry) => entry.key.startsWith(prefix))
        .expand((entry) => entry.value)
        .toList();
    if (pendingWrites.isNotEmpty) {
      try {
        await Future.wait(pendingWrites);
      } catch (_) {
        // Still remove every key that the storage backend successfully wrote.
      }
    }

    final values = await _storage.readAll();
    final matchingKeys = values.keys
        .where((key) => key.startsWith(prefix))
        .toList();
    for (final key in matchingKeys) {
      await _storage.delete(key: key);
    }
  }

  /// Re-enables writes for a user's namespace after they authenticate.
  void allowWritesWithPrefix(String prefix) {
    _blockedPrefixes.remove(prefix);
  }

  Future<void> clearAll() async {
    _sessionToken = null;
    await _storage.deleteAll();
  }
}
