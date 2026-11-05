import 'dart:async';
import 'dart:io';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockSecureStorageService extends Mock implements SecureStorageService {}

void main() {
  group('AuthNotifier.loginWithGoogle redirect timeout', () {
    late MockAuthRepository repository;
    late MockSecureStorageService storage;
    late ProviderContainer container;
    Uri? launched;
    late int port;

    setUp(() async {
      // Claim a free port and release it, so the flow under test binds a port
      // nothing else holds. Hard-coding 8000 fails whenever something else
      // has it, which has nothing to do with the behaviour being tested.
      final probe = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      port = probe.port;
      await probe.close();

      repository = MockAuthRepository();
      storage = MockSecureStorageService();
      launched = null;

      when(() => storage.getAccessToken()).thenAnswer((_) async => null);
      when(() => storage.deleteAccessToken()).thenAnswer((_) async {});

      locator.registerSingleton<SecureStorageService>(storage);
      locator.registerSingleton<AuthInterceptor>(
        AuthInterceptor(storage: storage),
      );
      locator.registerSingleton<AppConfig>(
        const AppConfig(
          apiBaseUrl: 'https://example.com/',
          usesMockData: false,
        ),
      );

      container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
          // A real bound, just a short one: the loopback server is a real
          // socket, so fakeAsync cannot drive this stream's timeout.
          googleRedirectTimeoutProvider.overrideWithValue(
            const Duration(milliseconds: 50),
          ),
          googleRedirectPortProvider.overrideWithValue(port),
          externalUrlLauncherProvider.overrideWithValue((uri) async {
            launched = uri;
            return true;
          }),
        ],
      );
      addTearDown(container.dispose);
    });

    tearDown(() async {
      await locator.reset();
    });

    // The notifier restores the session on build; let that finish first so it
    // cannot overwrite the state the sign-in attempt sets.
    Future<void> settleRestore() {
      final completer = Completer<void>();
      final subscription = container.listen<AuthState>(authNotifierProvider, (
        previous,
        next,
      ) {
        if (next.status != AuthStatus.unknown && !completer.isCompleted) {
          completer.complete();
        }
      }, fireImmediately: true);
      addTearDown(subscription.close);
      return completer.future.timeout(const Duration(seconds: 2));
    }

    test(
      'gives up waiting, reports the timeout and frees the loopback port',
      () async {
        await settleRestore();
        final notifier = container.read(authNotifierProvider.notifier);

        await notifier.loginWithGoogle();

        final state = container.read(authNotifierProvider);
        expect(
          launched?.host,
          'accounts.google.com',
          reason: 'the consent page should have been opened',
        );
        expect(
          state.isLoading,
          isFalse,
          reason: 'the button must leave its loading state',
        );
        expect(state.error, 'Google Sign-In timed out. Please try again.');

        // Binding would throw if the loopback server were still listening,
        // which is what made the retry impossible before the fix.
        final rebind = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          port,
        );
        addTearDown(rebind.close);
      },
    );
  });
}
