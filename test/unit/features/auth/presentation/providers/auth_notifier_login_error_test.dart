import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockSecureStorageService extends Mock implements SecureStorageService {}

void main() {
  group('AuthNotifier login error mapping', () {
    late MockAuthRepository repository;
    late MockSecureStorageService storage;
    late ProviderContainer container;

    setUp(() {
      repository = MockAuthRepository();
      storage = MockSecureStorageService();

      when(() => storage.getAccessToken()).thenAnswer((_) async => null);
      when(() => storage.deleteAccessToken()).thenAnswer((_) async {});
      when(
        () => storage.saveAccessToken(any(), persist: any(named: 'persist')),
      ).thenAnswer((_) async {});

      locator.registerSingleton<SecureStorageService>(storage);
      locator.registerSingleton<AuthInterceptor>(
        AuthInterceptor(storage: storage),
      );

      container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
    });

    tearDown(() async {
      await locator.reset();
    });

    test(
      'displays generic credential error when login fails with client error',
      () async {
        when(
          () => repository.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer(
          (_) async => const Failure<AuthSession>(
            ApiFailure(
              message: 'Invalid email and password supplied',
              kind: ApiFailureKind.client,
              statusCode: 400,
            ),
          ),
        );

        final notifier = container.read(authNotifierProvider.notifier);
        await notifier.login(
          email: 'test@example.com',
          password: 'wrongpassword',
        );

        final state = container.read(authNotifierProvider);
        expect(state.isLoading, false);
        expect(
          state.error,
          'Invalid email or password. Please check your credentials and try again.',
        );
      },
    );

    test(
      'displays generic credential error when login fails with 401 unauthorized',
      () async {
        when(
          () => repository.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer(
          (_) async => const Failure<AuthSession>(
            ApiFailure(
              message: 'Unauthorized',
              kind: ApiFailureKind.unauthorized,
              statusCode: 401,
            ),
          ),
        );

        final notifier = container.read(authNotifierProvider.notifier);
        await notifier.login(
          email: 'test@example.com',
          password: 'wrongpassword',
        );

        final state = container.read(authNotifierProvider);
        expect(state.isLoading, false);
        expect(
          state.error,
          'Invalid email or password. Please check your credentials and try again.',
        );
      },
    );

    test('preserves network error message on connection failure', () async {
      when(
        () => repository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer(
        (_) async => const Failure<AuthSession>(
          ApiFailure(
            message: 'Connection failed',
            kind: ApiFailureKind.network,
          ),
        ),
      );

      final notifier = container.read(authNotifierProvider.notifier);
      await notifier.login(email: 'test@example.com', password: 'password');

      final state = container.read(authNotifierProvider);
      expect(state.isLoading, false);
      expect(
        state.error,
        'No internet connection. Check your network and try again.',
      );
    });

    test('preserves server error message on 500 error', () async {
      when(
        () => repository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer(
        (_) async => const Failure<AuthSession>(
          ApiFailure(
            message: 'Internal server error',
            kind: ApiFailureKind.server,
            statusCode: 500,
          ),
        ),
      );

      final notifier = container.read(authNotifierProvider.notifier);
      await notifier.login(email: 'test@example.com', password: 'password');

      final state = container.read(authNotifierProvider);
      expect(state.isLoading, false);
      expect(
        state.error,
        'Something went wrong on our end. Please try again later.',
      );
    });
  });
}
