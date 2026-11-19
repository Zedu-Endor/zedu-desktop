import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';

void main() {
  group('AppConfig googleClientId defaults', () {
    setUpAll(() {
      // Mirror an empty/absent `.env` value so fromEnvironment can read
      // dotenv keys and still fall through to the built-in default.
      dotenv.loadFromString(envString: 'GOOGLE_CLIENT_ID=');
    });

    test(
      'constructor default and fromEnvironment fallback are the same id',
      () {
        const direct = AppConfig(
          apiBaseUrl: 'https://example.com/',
          usesMockData: false,
        );
        final viaEnvironment = AppConfig.fromEnvironment();

        expect(direct.googleClientId, kDefaultDesktopGoogleClientId);
        expect(
          viaEnvironment.googleClientId,
          direct.googleClientId,
          reason:
              'AppConfig() and AppConfig.fromEnvironment() must resolve to '
              'the same default desktop Google client id',
        );
      },
    );
  });

  group('AppConfig API host default', () {
    setUpAll(() {
      // Mirror an absent `API_BASE_URL` so fromEnvironment has to fall back.
      dotenv.loadFromString(envString: 'API_BASE_URL=');
    });

    test('release builds default to the production host', () {
      expect(defaultApiBaseUrl(isRelease: true), kProductionApiBaseUrl);
      expect(kProductionApiBaseUrl, 'https://api.zedu.chat/api/v1/');
    });

    test('debug and profile builds default to staging', () {
      expect(defaultApiBaseUrl(isRelease: false), kStagingApiBaseUrl);
      expect(kStagingApiBaseUrl, 'https://api.staging.zedu.chat/api/v1/');
    });

    test('fromEnvironment uses the build-mode default', () {
      final config = AppConfig.fromEnvironment();

      expect(config.apiBaseUrl, defaultApiBaseUrl(isRelease: kReleaseMode));
    });
  });
}
