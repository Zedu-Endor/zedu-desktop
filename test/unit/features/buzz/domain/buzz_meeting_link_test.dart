import 'package:zedu/features/features.dart';

import '../../../../helpers/helpers.dart';

void main() {
  group('buzzMeetingCode', () {
    test('takes a bare code as it is', () {
      expect(buzzMeetingCode('  abc-defg-hij '), 'abc-defg-hij');
    });

    test('takes the last part of a link, without query or fragment', () {
      expect(
        buzzMeetingCode('https://zedu.chat/acme/buzz/abc-defg-hij?direct=1#x'),
        'abc-defg-hij',
      );
      expect(buzzMeetingCode('zedu.chat/acme/buzz/abc/'), 'abc');
    });

    test('is empty when nothing usable was typed', () {
      expect(buzzMeetingCode('   '), '');
      expect(buzzMeetingCode('///'), '');
    });
  });

  test('buzzMeetingUrl builds the web meeting page', () {
    expect(
      buzzMeetingUrl(
        webBaseUrl: 'https://zedu.chat',
        orgSlug: 'acme',
        code: 'abc-defg-hij',
      ).toString(),
      'https://zedu.chat/acme/buzz/abc-defg-hij',
    );
    expect(
      buzzMeetingUrl(
        webBaseUrl: 'https://zedu.chat',
        orgSlug: 'acme',
        code: 'abc',
        directJoin: true,
      ).toString(),
      'https://zedu.chat/acme/buzz/abc?direct=1',
    );
  });
}
