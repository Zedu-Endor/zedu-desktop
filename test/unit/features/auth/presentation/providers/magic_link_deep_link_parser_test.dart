import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

void main() {
  group('MagicLinkDeepLinkParser', () {
    test('extracts token from custom zedu scheme link', () {
      final uri = Uri.parse('zedu://auth/magick-link/verify?token=abc123');

      final token = MagicLinkDeepLinkParser.extractToken(uri);

      expect(token, 'abc123');
    });

    test('extracts token from https auth link', () {
      final uri = Uri.parse(
        'https://api.staging.zedu.chat/auth/magick-link/verify?token=abc123',
      );

      final token = MagicLinkDeepLinkParser.extractToken(uri);

      expect(token, 'abc123');
    });

    test('extracts token from the link the server emails (#81)', () {
      // The server builds the link as <Referer>auth/login/magic-link?token=…
      // and the app sends emailLinkBase as Referer.
      final uri = Uri.parse(
        '${MagicLinkDeepLinkParser.emailLinkBase}'
        'auth/login/magic-link?token=482913',
      );

      final token = MagicLinkDeepLinkParser.extractToken(uri);

      expect(token, '482913');
    });

    test('returns null for missing token query parameter', () {
      final uri = Uri.parse('zedu://auth/magick-link/verify');

      final token = MagicLinkDeepLinkParser.extractToken(uri);

      expect(token, isNull);
    });

    test('returns null for unsupported path', () {
      final uri = Uri.parse('zedu://auth/magick-link?token=abc123');

      final token = MagicLinkDeepLinkParser.extractToken(uri);

      expect(token, isNull);
    });
  });
}
