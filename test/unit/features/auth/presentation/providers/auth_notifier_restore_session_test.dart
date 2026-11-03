import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockSecureStorageService extends Mock implements SecureStorageService {}

void main() {
  group('AuthNotifier session restore', () {
    late MockAuthRepository repository;
    late MockSecureStorageService storage;
    late ProviderContainer container;

    setUp(() {
      repository = MockAuthRepository();
      storage = MockSecureStorageService();

      when(() => storage.deleteAccessToken()).thenAnswer((_) async {});

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

    // Starts the notifier and waits until it has finished restoring.
    Future<AuthState> restoreSession() {
      final completer = Completer<AuthState>();
      final subscription = container.listen<AuthState>(authNotifierProvider, (
        previous,
        next,
      ) {
        if (next.status != AuthStatus.unknown && !completer.isCompleted) {
          completer.complete(next);
        }
      }, fireImmediately: true);
      addTearDown(subscription.close);
      return completer.future.timeout(const Duration(seconds: 2));
    }

    void givenSavedTokenAndFailure(ApiFailure failure) {
      when(
        () => storage.getAccessToken(),
      ).thenAnswer((_) async => 'saved-token');
      when(
        () => repository.getCurrentUser(),
      ).thenAnswer((_) async => Failure<User>(failure));
    }

    for (final kind in [
      ApiFailureKind.network,
      ApiFailureKind.timeout,
      ApiFailureKind.server,
    ]) {
      test('keeps the saved token when /auth/me fails with $kind', () async {
        final failure = ApiFailure(message: 'boom', kind: kind);
        givenSavedTokenAndFailure(failure);

        final state = await restoreSession();

        verifyNever(() => storage.deleteAccessToken());
        expect(state.status, AuthStatus.unauthenticated);
        expect(state.error, failure.friendlyMessage);
      });
    }

    test('deletes the saved token when /auth/me returns 401', () async {
      givenSavedTokenAndFailure(
        const ApiFailure(
          message: 'Unauthorized',
          statusCode: 401,
          kind: ApiFailureKind.unauthorized,
        ),
      );

      final state = await restoreSession();

      verify(() => storage.deleteAccessToken()).called(1);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.error, isNull);
    });

    test('clears the signed-in user drafts when logging out', () async {
      final user = User(
        id: 'user-1',
        firstName: 'Test',
        lastName: 'User',
        email: 'test@example.com',
        phone: '',
        username: 'test-user',
        isVerified: true,
        isOnboarded: true,
        createdAt: DateTime(2026),
        currentOrg: 'org-1',
        currentOrganisationSlug: 'org-1',
        avatarUrl: '',
        defaultAvatarUrl: '',
      );
      when(() => storage.getAccessToken()).thenAnswer((_) async => null);
      when(
        () => repository.login(email: 'test@example.com', password: 'password'),
      ).thenAnswer(
        (_) async => Success<AuthSession>(
          AuthSession(
            user: user,
            accessToken: 'token-1',
            accessTokenExpiresIn: DateTime(2027),
          ),
        ),
      );
      when(
        () => storage.saveAccessToken('token-1', persist: true),
      ).thenAnswer((_) async {});
      when(
        () => storage.deleteValuesWithPrefix('dm_draft_user-1_'),
      ).thenAnswer((_) async {});

      await restoreSession();
      final notifier = container.read(authNotifierProvider.notifier);
      await notifier.login(email: 'test@example.com', password: 'password');

      await notifier.logout();

      verify(
        () => storage.deleteValuesWithPrefix('dm_draft_user-1_'),
      ).called(1);
      verify(() => storage.allowWritesWithPrefix('dm_draft_user-1_')).called(1);
      verify(() => storage.deleteAccessToken()).called(1);
      expect(
        container.read(authNotifierProvider).status,
        AuthStatus.unauthenticated,
      );
    });
  });
}
