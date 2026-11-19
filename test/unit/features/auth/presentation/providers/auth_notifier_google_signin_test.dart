import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockSecureStorageService extends Mock implements SecureStorageService {}

class MockAuthInterceptor extends Mock implements AuthInterceptor {}

class _FakeUrlLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async => true;
}

void main() {
  group('AuthNotifier.loginWithGoogle deadline', () {
    test(
      'a cancelled browser flow ends the wait and clears the loading state',
      () async {
        final originalLauncher = UrlLauncherPlatform.instance;
        UrlLauncherPlatform.instance = _FakeUrlLauncher();
        addTearDown(() => UrlLauncherPlatform.instance = originalLauncher);

        final storage = MockSecureStorageService();
        locator.registerSingleton<SecureStorageService>(storage);
        locator.registerSingleton<AuthInterceptor>(MockAuthInterceptor());
        locator.registerSingleton<AppConfig>(
          const AppConfig(
            apiBaseUrl: 'https://example.com',
            usesMockData: true,
          ),
        );
        addTearDown(locator.reset);

        final repo = MockAuthRepository();
        final container = ProviderContainer(
          overrides: [authRepositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);

        when(() => storage.getAccessToken()).thenAnswer((_) async => null);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final notifier = container.read(authNotifierProvider.notifier);
        notifier.googleSignInWait = const Duration(milliseconds: 200);

        final login = notifier.loginWithGoogle();
        expect(container.read(authNotifierProvider).isLoading, isTrue);

        // No redirect ever arrives, so only the deadline can end the wait.
        // It must complete instead of hanging the sign-in forever.
        await login.timeout(const Duration(seconds: 10));

        expect(container.read(authNotifierProvider).isLoading, isFalse);
      },
    );
  });
}
