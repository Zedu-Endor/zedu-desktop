import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

void main() {
  group('ConversationSearchHit.fromResponse', () {
    test('flattens grouped results newest first with plain text', () {
      final hits = ConversationSearchHit.fromResponse([
        {
          'user': {'user_name': 'Ada Obi', 'user_id': 'u1'},
          'messages': [
            {
              'message_id': 'm1',
              'message': '<p>Budget review &amp; plan</p>',
              'timestamp': '2026-11-01T10:00:00Z',
            },
          ],
        },
        {
          'user': {'user_name': 'Bayo', 'user_id': 'u2'},
          'thread': {'id': 't9'},
          'messages': [
            {
              'message_id': 'm2',
              'message': 'Budget is approved',
              'timestamp': '2026-11-03T10:00:00Z',
            },
          ],
        },
      ]);

      expect(hits.map((hit) => hit.messageId), ['m2', 'm1']);
      expect(hits.first.userName, 'Bayo');
      expect(hits.first.threadId, 't9');
      expect(hits.last.text, 'Budget review & plan');
      expect(hits.last.threadId, isNull);
    });

    test('shows what was written, without tags or HTML entities', () {
      expect(
        ConversationSearchHit.plainText('<p>hello <strong>team</strong></p>'),
        'hello team',
      );
      expect(
        ConversationSearchHit.plainText('<p>Tom &amp; Jerry &lt;3</p>'),
        'Tom & Jerry <3',
      );
    });

    test('decodes entities that arrived escaped twice', () {
      expect(
        ConversationSearchHit.plainText('<p>Hello&amp;nbsp;</p>'),
        'Hello',
      );
      expect(
        ConversationSearchHit.plainText('<p>one&amp;nbsp;two</p>'),
        'one two',
      );
    });

    test('keeps separate paragraphs on separate lines', () {
      expect(
        ConversationSearchHit.plainText(
          '<p>first line</p><p>second line<br>third</p>',
        ),
        'first line\nsecond line\nthird',
      );
    });

    test('keeps angle brackets that the sender typed', () {
      expect(
        ConversationSearchHit.plainText('<p>Use List&lt;String&gt; here</p>'),
        'Use List<String> here',
      );
      expect(
        ConversationSearchHit.plainText('Ada <ada@zedu.chat> wrote'),
        'Ada <ada@zedu.chat> wrote',
      );
      expect(
        ConversationSearchHit.plainText('wrap it in a <div> element'),
        'wrap it in a <div> element',
      );
    });

    test('skips messages without an id and survives odd data', () {
      expect(ConversationSearchHit.fromResponse(null), isEmpty);
      expect(ConversationSearchHit.fromResponse({'data': 1}), isEmpty);
      final hits = ConversationSearchHit.fromResponse([
        {
          'messages': [
            {'message': 'no id'},
            {'message_id': 'm3', 'message': 'kept'},
          ],
        },
      ]);
      expect(hits.single.messageId, 'm3');
      expect(hits.single.userName, 'Unknown');
      expect(hits.single.sentAt, isNull);
    });
  });
}
