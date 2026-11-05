import '../../../../helpers/helpers.dart';
import 'package:zedu/features/features.dart';

void main() {
  test('ChannelMessage.fromJson maps a thread', () {
    final message = ChannelMessage.fromJson({
      'thread_id': 't-1',
      'full_name': 'Ada Lovelace',
      'avatar_url': 'https://cdn.zedu.chat/a.png',
      'message': 'hello',
      'created_at': '2026-10-21T05:14:46Z',
    });

    expect(message.senderName, 'Ada Lovelace');
    expect(message.avatarUrl, 'https://cdn.zedu.chat/a.png');
    expect(message.createdAt, DateTime.utc(2026, 10, 21, 5, 14, 46).toLocal());
  });

  test('ChannelMessage.fromJson converts HTML to Markdown with lists', () {
    final message = ChannelMessage.fromJson({
      'full_name': ' ',
      'username': 'gold_salam',
      'default_avatar_url': 'https://cdn.zedu.chat/default.png',
      'message':
          '<p>Hi &amp; welcome</p><div>Line&nbsp;two</div><ul><li>a</li><li>b</li></ul>',
    });

    expect(message.senderName, 'gold_salam');
    expect(message.avatarUrl, 'https://cdn.zedu.chat/default.png');
    expect(message.text, 'Hi & welcome\nLine two\n• a\n• b');
  });

  test(
    'ChannelMessage.fromJson preserves generic types and angle brackets',
    () {
      expect(
        ChannelMessage.fromJson({'message': 'List<String>'}).text,
        'List<String>',
      );
      expect(
        ChannelMessage.fromJson({'message': 'Map<String, int>'}).text,
        'Map<String, int>',
      );
      expect(
        ChannelMessage.fromJson({'message': '<help@zedu.chat>'}).text,
        '<help@zedu.chat>',
      );
      expect(
        ChannelMessage.fromJson({'message': 'if a < b and c > d'}).text,
        'if a < b and c > d',
      );
      expect(
        ChannelMessage.fromJson({
          'message': '<p>Here is <strong>bold</strong> and List<String></p>',
        }).text,
        'Here is **bold** and List<String>',
      );
    },
  );

  group('ChannelMessage.fromJson decodes HTML entities', () {
    String textOf(String html) =>
        ChannelMessage.fromJson({'message': html}).text;

    test('shows the characters the web editor escapes', () {
      expect(textOf('<p>if a &lt; b and b &gt; c</p>'), 'if a < b and b > c');
      expect(textOf('<p>I &lt;3 this</p>'), 'I <3 this');
      expect(
        textOf('<p>&quot;quoted&quot; &apos;text&apos;</p>'),
        '"quoted" \'text\'',
      );
    });

    test('decodes numeric entities', () {
      expect(textOf('it&#39;s &#x27;ok&#X27; &#128512;'), "it's 'ok' 😀");
    });

    test('decodes once, so an escaped entity stays as typed', () {
      expect(textOf('<p>type &amp;lt; for &lt;</p>'), 'type &lt; for <');
    });

    test('leaves anything that is not a valid entity alone', () {
      expect(
        textOf('AT&T &bogus; &#xFFFFFFF; &#xD800; &lt'),
        'AT&T &bogus; &#xFFFFFFF; &#xD800; &lt',
      );
    });
  });
}
