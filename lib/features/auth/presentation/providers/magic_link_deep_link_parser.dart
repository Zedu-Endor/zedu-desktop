class MagicLinkDeepLinkParser {
  const MagicLinkDeepLinkParser._();

  /// What the desktop app sends as `Referer` when it asks for a magic link.
  /// The server builds the emailed link from that header as
  /// `<Referer>auth/login/magic-link?token=…`, so this makes it
  /// `zedu://auth/login/magic-link?token=…`, which opens the app. Without it
  /// the link has no host and opens a browser error page (Ziki #81).
  static const emailLinkBase = 'zedu://';

  static String? extractToken(Uri uri) {
    if (!_isSupportedMagicLinkUri(uri)) return null;
    final token = uri.queryParameters['token']?.trim();
    if (token == null || token.isEmpty) return null;
    return token;
  }

  static bool _isSupportedMagicLinkUri(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    final path = _normalizePath(uri.path);

    if (scheme == 'zedu' &&
        host == 'auth' &&
        (path == '/login/magic-link' || path == '/magick-link/verify')) {
      return true;
    }

    if ((scheme == 'https' || scheme == 'http') &&
        path.endsWith('/auth/magick-link/verify')) {
      return true;
    }

    return false;
  }

  static String _normalizePath(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return '/';
    return trimmed.startsWith('/') ? trimmed : '/$trimmed';
  }
}
