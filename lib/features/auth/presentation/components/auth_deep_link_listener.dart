import 'dart:async';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class AuthDeepLinkListener extends ConsumerStatefulWidget {
  const AuthDeepLinkListener({super.key, required this.child, this.appLinks});

  final Widget child;
  final AppLinks? appLinks;

  @override
  ConsumerState<AuthDeepLinkListener> createState() =>
      _AuthDeepLinkListenerState();
}

class _AuthDeepLinkListenerState extends ConsumerState<AuthDeepLinkListener> {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  // The token whose verification is running right now, and the last token
  // that signed the user in. Either one is ignored if it is delivered again;
  // a token whose verification failed can be tapped again to retry.
  String? _inFlightToken;
  String? _verifiedToken;

  static const _tag = 'AuthDeepLinkListener';

  @override
  void initState() {
    super.initState();
    _appLinks = widget.appLinks ?? AppLinks();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        await _handleUri(initialUri);
      }
    } catch (error) {
      AppLogger.w('Failed to read initial deep link', tag: _tag);
    }

    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        unawaited(_handleUri(uri));
      },
      onError: (Object error, StackTrace stackTrace) {
        AppLogger.w('Deep link stream error: $error', tag: _tag);
      },
    );
  }

  Future<void> _handleUri(Uri uri) async {
    final token = MagicLinkDeepLinkParser.extractToken(uri);
    if (token == null || token == _inFlightToken || token == _verifiedToken) {
      return;
    }
    _inFlightToken = token;

    AppLogger.i('Processing magic link deep link', tag: _tag);
    final auth = ref.read(authNotifierProvider.notifier);
    try {
      await auth.verifyMagicLink(token: token);
    } finally {
      if (_inFlightToken == token) _inFlightToken = null;
    }

    if (!mounted) return;

    final authState = ref.read(authNotifierProvider);
    if (authState.status == AuthStatus.authenticated) {
      _verifiedToken = token;
    }

    // This listener is mounted from `App`'s builder, above the Navigator, so
    // its own context has neither an Overlay nor the router in it.
    final navigator = AppRouter.navigatorKey.currentState;
    if (navigator == null) return;

    if (authState.status == AuthStatus.authenticated) {
      AppToastService.showAtRoot(
        navigator,
        type: AppToastType.success,
        message: 'Logged in successfully!',
      );
      navigator.context.go(AppRouter.home);
      return;
    }

    if (authState.error != null) {
      AppToastService.showAtRoot(
        navigator,
        type: AppToastType.error,
        message: authState.error!,
      );
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
