import 'package:zedu/core/core.dart';

class SecureStorageService {
  SecureStorageService() : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'access_token';

  Future<void> saveAccessToken(String token) =>
      _storage.write(key: _accessTokenKey, value: token);

  Future<String?> getAccessToken() => _storage.read(key: _accessTokenKey);

  Future<void> deleteAccessToken() => _storage.delete(key: _accessTokenKey);

  Future<void> writeData(String key, String value) =>
      _storage.write(key: key, value: value);
  Future<String?> readData(String key) => _storage.read(key: key);

  Future<void> deleteValue(String key) => _storage.delete(key: key);

  Future<void> clearAll() => _storage.deleteAll();
}
