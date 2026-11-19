import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockSecureStorageService extends Mock implements SecureStorageService {}

void main() {
  group('AuthNotifier unauthorized callback lifecycle', () {
    late MockAuthRepository repository;
    late MockSecureStorageService storage;
    late ProviderContainer container;

    setUp(() {
      repository = MockAuthRepository();
      storage = MockSecureStorageService();

      when(() => storage.deleteAccessToken()).thenAnswer((_) async {});
      when(() => storage.getAccessToken()).thenAnswer((_) async => null);

      locator.registerSingleton<SecureStorageService>(storage);
      locator.registerSingleton<AuthInterceptor>(
        AuthInterceptor(storage: storage),
      );

      container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
    });

    tearDown(() async {
      await locator.reset();
    });

    Future<void> waitForInit() async {
      final completer = Completer<void>();
      final sub = container.listen<AuthState>(authNotifierProvider, (
        prev,
        next,
      ) {
        if (next.status != AuthStatus.unknown && !completer.isCompleted) {
          completer.complete();
        }
      }, fireImmediately: true);
      addTearDown(sub.close);
      await completer.future.timeout(const Duration(seconds: 2));
    }

    test(
      'clears onUnauthorized on interceptor when container is disposed',
      () async {
        final interceptor = locator<AuthInterceptor>();
        await waitForInit();
        expect(interceptor.onUnauthorized, isNotNull);

        container.dispose();

        expect(interceptor.onUnauthorized, isNull);
      },
    );

    test(
      'ignores onUnauthorized callback if invoked after disposal without throwing StateError',
      () async {
        final interceptor = locator<AuthInterceptor>();
        await waitForInit();
        final capturedCallback = interceptor.onUnauthorized;
        expect(capturedCallback, isNotNull);

        container.dispose();

        expect(() => capturedCallback!(), returnsNormally);
      },
    );
  });
}
