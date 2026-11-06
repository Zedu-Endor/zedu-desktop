import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

void main() {
  group('messagePreviewText', () {
    test('keeps angle brackets that carry content', () {
      expect(messagePreviewText('List<String>'), 'List<String>');
      expect(messagePreviewText('Map<String, int>'), 'Map<String, int>');
      expect(messagePreviewText('<help@zedu.chat>'), '<help@zedu.chat>');
      expect(messagePreviewText('a < b and c > d'), 'a < b and c > d');
    });

    test('drops real HTML tags but keeps their text', () {
      expect(messagePreviewText('<p>Hello</p>'), 'Hello');
      expect(
        messagePreviewText('<p>Hello <strong>Ada</strong></p>'),
        'Hello Ada',
      );
      expect(
        messagePreviewText(
          '<p>Deploy <strong>List&lt;String&gt;</strong> now</p>',
        ),
        'Deploy List<String> now',
      );
    });

    test('decodes entities, trims and collapses whitespace', () {
      expect(
        messagePreviewText('<p>Tom &amp; Jerry &lt;3</p>'),
        'Tom & Jerry <3',
      );
      expect(
        messagePreviewText('  See   you at standup  '),
        'See you at standup',
      );
    });
  });
}
