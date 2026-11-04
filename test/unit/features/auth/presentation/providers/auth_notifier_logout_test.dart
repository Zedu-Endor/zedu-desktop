import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockSecureStorageService extends Mock implements SecureStorageService {}

class MockAuthInterceptor extends Mock implements AuthInterceptor {}

void main() {
  late MockAuthRepository repository;
  late MockSecureStorageService storage;
  late ProviderContainer container;
  late List<String> calls;

  setUp(() async {
    repository = MockAuthRepository();
    storage = MockSecureStorageService();
    calls = [];
    locator.registerSingleton<SecureStorageService>(storage);
    locator.registerSingleton<AuthInterceptor>(MockAuthInterceptor());
    addTearDown(locator.reset);

    when(() => storage.getAccessToken()).thenAnswer((_) async => null);
    when(() => storage.deleteAccessToken()).thenAnswer((_) async {
      calls.add('delete token');
    });

    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    container.read(authNotifierProvider);
    await pumpEventQueue();
  });

  test('revokes the session on the server before clearing the token', () async {
    when(() => repository.logout()).thenAnswer((_) async {
      calls.add('revoke');
      return const Success(null);
    });

    await container.read(authNotifierProvider.notifier).logout();

    expect(calls, ['revoke', 'delete token']);
    expect(
      container.read(authNotifierProvider).status,
      AuthStatus.unauthenticated,
    );
  });

  test('still signs out locally when the request fails', () async {
    when(() => repository.logout()).thenAnswer(
      (_) async => const Failure<void>(
        ApiFailure(message: 'offline', kind: ApiFailureKind.network),
      ),
    );

    await container.read(authNotifierProvider.notifier).logout();

    expect(calls, ['delete token']);
    expect(
      container.read(authNotifierProvider).status,
      AuthStatus.unauthenticated,
    );
  });

  testWidgets('still signs out locally when the request never answers', (
    tester,
  ) async {
    when(
      () => repository.logout(),
    ).thenAnswer((_) => Completer<Result<void>>().future);

    var finished = false;
    unawaited(
      container.read(authNotifierProvider.notifier).logout().then((_) {
        finished = true;
      }),
    );
    await tester.pump(AuthNotifier.logoutRequestTimeout);

    expect(finished, isTrue);
    expect(calls, ['delete token']);
    expect(
      container.read(authNotifierProvider).status,
      AuthStatus.unauthenticated,
    );
  });
}
