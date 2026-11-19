import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';

class _MemoryStorage extends SecureStorageService {
  _MemoryStorage(this.token);

  String? token;
  int deletes = 0;

  @override
  Future<String?> getAccessToken() async => token;

  @override
  Future<void> deleteAccessToken() async {
    deletes++;
    token = null;
  }
}

class _DelayedResponseAdapter implements HttpClientAdapter {
  final requestStarted = Completer<void>();
  final response = Completer<ResponseBody>();

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requestStarted.complete();
    return response.future;
  }
}

void main() {
  test('a delayed 401 does not clear a newer access token', () async {
    final storage = _MemoryStorage('token-a');
    final adapter = _DelayedResponseAdapter();
    var unauthorized = 0;
    final dio = Dio(BaseOptions(baseUrl: 'http://example.test/'))
      ..httpClientAdapter = adapter
      ..interceptors.add(
        AuthInterceptor(storage: storage)
          ..onUnauthorized = () => unauthorized++,
      );

    final request = dio
        .get<dynamic>('messages')
        .then<Object>((response) => response, onError: (Object error) => error);
    await adapter.requestStarted.future;

    storage.token = 'token-b';
    adapter.response.complete(ResponseBody.fromString('{"ok":false}', 401));

    expect(await request, isA<DioException>());
    expect(storage.token, 'token-b');
    expect(storage.deletes, 0);
    expect(unauthorized, 0);
  });

  test('a current-session 401 clears its matching access token', () async {
    final storage = _MemoryStorage('token-a');
    final dio = Dio(BaseOptions(baseUrl: 'http://example.test/'))
      ..httpClientAdapter = _StatusAdapter(401);
    var unauthorized = 0;
    dio.interceptors.add(
      AuthInterceptor(storage: storage)..onUnauthorized = () => unauthorized++,
    );

    final result = await dio
        .get<dynamic>('messages')
        .then<Object>((response) => response, onError: (Object error) => error);

    expect(result, isA<DioException>());
    expect(storage.token, isNull);
    expect(storage.deletes, 1);
    expect(unauthorized, 1);
  });
}

class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter(this.status);

  final int status;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString('{"ok":false}', status);
}
