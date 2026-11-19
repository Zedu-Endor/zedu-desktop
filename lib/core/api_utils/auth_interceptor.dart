import 'package:zedu/core/core.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor({required SecureStorageService storage}) : _storage = storage;

  final SecureStorageService _storage;
  VoidCallback? onUnauthorized;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await _storage.getAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (error) {
      // Secure storage can throw (for example from corrupted stored data).
      // Send the request without a token so the call still completes and the
      // normal 401 handling takes over, instead of hanging forever.
      AppLogger.w(
        'Could not read the access token: $error',
        tag: 'AuthInterceptor',
      );
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final requestToken = _bearerToken(_authorizationHeader(err.requestOptions));
    if (err.response?.statusCode == 401 && requestToken != null) {
      var belongsToCurrentSession = false;
      try {
        // A late 401 from an earlier request must not invalidate a session
        // established after that request was sent.
        belongsToCurrentSession =
            await _storage.getAccessToken() == requestToken;
        if (belongsToCurrentSession) {
          await _storage.deleteAccessToken();
        }
      } catch (error) {
        AppLogger.w(
          'Could not delete the access token: $error',
          tag: 'AuthInterceptor',
        );
      }
      if (belongsToCurrentSession) onUnauthorized?.call();
    }
    handler.next(err);
  }

  Object? _authorizationHeader(RequestOptions options) {
    for (final entry in options.headers.entries) {
      if (entry.key.toLowerCase() == 'authorization') return entry.value;
    }
    return null;
  }

  String? _bearerToken(Object? authorization) {
    if (authorization is! String || !authorization.startsWith('Bearer ')) {
      return null;
    }
    final token = authorization.substring('Bearer '.length).trim();
    return token.isEmpty ? null : token;
  }
}
