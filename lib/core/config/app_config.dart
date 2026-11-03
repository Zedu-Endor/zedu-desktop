import 'package:zedu/core/core.dart';

/// Default Google OAuth client id for the **desktop** client type; it applies
/// whenever `GOOGLE_CLIENT_ID` comes from neither `--dart-define` nor `.env`.
///
/// This is the id the app actually runs with: the locator registers
/// [AppConfig.fromEnvironment], whose fallback reads this constant, and the
/// [AppConfig] constructor default reads it too, so direct construction and
/// environment resolution can never disagree. For reference, the **web**
/// client id used by browser builds is
/// `764182056638-bi8bet0rdoabaeq24bqsdnb5iukn7ko4.apps.googleusercontent.com`.
const String kDefaultDesktopGoogleClientId =
    '764182056638-08g88e196e643mhpa2tuv5dpr7iumd1j.apps.googleusercontent.com';

class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.usesMockData,
    this.googleClientId = kDefaultDesktopGoogleClientId,
    this.googleClientSecret = '',
    this.webAppUrl = '',
  });

  /// Resolves config after [loadAppEnv] has run in [main] (root `.env` /
  /// `.env.example`, bundled as assets).
  ///
  /// Precedence: `--dart-define` wins, then dotenv keys from those files, then
  /// defaults. See [String.fromEnvironment](https://api.flutter.dev/flutter/dart-ui/String/String.fromEnvironment.html).
  factory AppConfig.fromEnvironment() {
    const defineApiBaseUrl = String.fromEnvironment('API_BASE_URL');
    const defineUsesMock = String.fromEnvironment('USE_MOCK_DATA');
    const defineClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
    const defineClientSecret = String.fromEnvironment('GOOGLE_CLIENT_SECRET');
    const defineWebAppUrl = String.fromEnvironment('WEB_APP_URL');

    final envApiBaseUrl = dotenv.maybeGet('API_BASE_URL')?.trim();
    final envUsesMock = dotenv.maybeGet('USE_MOCK_DATA')?.trim();
    final envClientId = dotenv.maybeGet('GOOGLE_CLIENT_ID')?.trim();
    final envClientSecret = dotenv.maybeGet('GOOGLE_CLIENT_SECRET')?.trim();
    final envWebAppUrl = dotenv.maybeGet('WEB_APP_URL')?.trim();

    // Teams point the app at their own backend via --dart-define or .env; Zedu staging is the default.
    String apiBaseUrl = defineApiBaseUrl.isNotEmpty
        ? defineApiBaseUrl
        : (envApiBaseUrl?.isNotEmpty ?? false)
        ? envApiBaseUrl!
        : 'https://api.staging.zedu.chat/api/v1/';

    apiBaseUrl = apiBaseUrl.replaceAll('"', '').replaceAll("'", "");

    if (!apiBaseUrl.endsWith('/')) {
      apiBaseUrl += '/';
    }

    final usesMockData = defineUsesMock.isNotEmpty
        ? _parseBool(defineUsesMock, defaultValue: false)
        : envUsesMock != null && envUsesMock.isNotEmpty
        ? _parseBool(envUsesMock, defaultValue: false)
        : false; // Changed to false so real backend is used by default

    final googleClientId = defineClientId.isNotEmpty
        ? defineClientId
        : (envClientId?.isNotEmpty ?? false)
        ? envClientId!
        : kDefaultDesktopGoogleClientId;

    final googleClientSecret = defineClientSecret.isNotEmpty
        ? defineClientSecret
        : (envClientSecret?.isNotEmpty ?? false)
        ? envClientSecret!
        : '';

    return AppConfig(
      apiBaseUrl: apiBaseUrl,
      usesMockData: usesMockData,
      googleClientId: googleClientId,
      googleClientSecret: googleClientSecret,
      webAppUrl: defineWebAppUrl.isNotEmpty
          ? defineWebAppUrl
          : envWebAppUrl ?? '',
    );
  }

  final String apiBaseUrl;
  final bool usesMockData;
  final String googleClientId;
  final String googleClientSecret;

  /// The web app's address, from `WEB_APP_URL`. Empty means [webBaseUrl]
  /// works it out from [apiBaseUrl].
  final String webAppUrl;

  /// Where the web app runs, without a trailing slash, for links that open
  /// in the browser (such as Buzz meetings). Defaults to the API host
  /// without its `api.` prefix: `https://api.zedu.chat/api/v1/` gives
  /// `https://zedu.chat`.
  String get webBaseUrl {
    final configured = webAppUrl.replaceAll('"', '').replaceAll("'", '').trim();
    if (configured.isNotEmpty) {
      return configured.endsWith('/')
          ? configured.substring(0, configured.length - 1)
          : configured;
    }
    final api = Uri.tryParse(apiBaseUrl);
    if (api == null || api.host.isEmpty) return 'https://zedu.chat';
    final host = api.host.startsWith('api.') ? api.host.substring(4) : api.host;
    return Uri(
      scheme: api.scheme.isEmpty ? 'https' : api.scheme,
      host: host,
      port: api.hasPort ? api.port : null,
    ).toString();
  }
}

bool _parseBool(String raw, {required bool defaultValue}) {
  final normalized = raw.trim().toLowerCase();
  if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
    return true;
  }
  if (normalized == 'false' || normalized == '0' || normalized == 'no') {
    return false;
  }
  return defaultValue;
}
