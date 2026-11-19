import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/dms/domain/notification_service.dart';

void main() {
  group('notificationPreview strips markup before truncating', () {
    test('removes tags and keeps the words around them', () {
      expect(
        notificationPreview('<p>Hello <strong>there</strong></p>'),
        'Hello there',
      );
    });

    test('decodes entities, including doubled ones', () {
      expect(notificationPreview('Hello&nbsp;world'), 'Hello world');
      expect(notificationPreview('Tom &amp; Jerry'), 'Tom & Jerry');
    });

    test('never cuts inside a tag when the text is long', () {
      final preview = notificationPreview('<p>${'a' * 90}</p>');
      expect(preview.contains('<'), isFalse);
      expect(preview.endsWith('...'), isTrue);
    });

    test('leaves plain text untouched', () {
      expect(notificationPreview('Just a message'), 'Just a message');
    });
  });
}
