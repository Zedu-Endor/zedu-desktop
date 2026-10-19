import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';

void main() {
  group('plainTextPreview', () {
    test('strips HTML tags from web messages', () {
      expect(plainTextPreview('<p>hey</p>'), 'hey');
      expect(
        plainTextPreview('<p>Hello <strong>team</strong></p><p>see you</p>'),
        'Hello team see you',
      );
    });

    test('keeps words apart across <br> tags with attributes', () {
      expect(plainTextPreview('Hello<br>World'), 'Hello World');
      expect(plainTextPreview('Hello<br/>World'), 'Hello World');
      expect(plainTextPreview('Hello<br class="break">World'), 'Hello World');
    });

    test('keeps list items apart when </li> is omitted', () {
      expect(plainTextPreview('<ul><li>First<li>Second</ul>'), 'First Second');
      expect(
        plainTextPreview('<ul><li class="x">First</li><li>Second</li></ul>'),
        'First Second',
      );
      expect(plainTextPreview('<link href="a">Hi'), 'Hi');
    });

    test('handles > inside quoted attribute values', () {
      expect(plainTextPreview('<a title="2 > 1">Open</a>'), 'Open');
    });

    test('keeps plain-text angle brackets that are not tags', () {
      expect(plainTextPreview('2 < 3 > 1'), '2 < 3 > 1');
    });

    test('decodes HTML entities', () {
      expect(
        plainTextPreview('<p>Tom &amp; Jerry &lt;3 &quot;hi&quot;</p>'),
        'Tom & Jerry <3 "hi"',
      );
    });

    test('removes inline Markdown markers from desktop messages', () {
      expect(
        plainTextPreview('**Fixed** it, *really* ~~maybe~~ `now`'),
        'Fixed it, really maybe now',
      );
    });

    test('decodes numeric character references', () {
      expect(
        plainTextPreview('<p>Hi &#128512; &#x1F600; &#39;ok&#x27;</p>'),
        "Hi 😀 😀 'ok'",
      );
      expect(
        plainTextPreview('&amp;#39; &#xD800; &#0;'),
        '&#39; &#xD800; &#0;',
      );
    });

    test('removes underscore emphasis but keeps underscores inside words', () {
      expect(
        plainTextPreview('an _important_ and __very important__ note'),
        'an important and very important note',
      );
      expect(
        plainTextPreview('keep snake_case_name and my_var'),
        'keep snake_case_name and my_var',
      );
    });

    test('shows the label of Markdown links and images', () {
      expect(
        plainTextPreview(
          'see [docs](https://example.com) and ![logo](https://x.png)',
        ),
        'see docs and logo',
      );
    });

    test('returns empty text for markup-only content', () {
      expect(plainTextPreview('<p></p>'), '');
      expect(plainTextPreview('   '), '');
    });

    test('keeps short text unchanged', () {
      expect(plainTextPreview('Hello! 👋'), 'Hello! 👋');
    });

    test('truncates long text to 80 characters with an ellipsis', () {
      final result = plainTextPreview('a' * 100);
      expect(result, '${'a' * 77}...');
    });

    test('cuts without an ellipsis when the limit is too short for one', () {
      expect(plainTextPreview('hello', maxLength: 3), 'hel');
      expect(plainTextPreview('hello', maxLength: 2), 'he');
      expect(plainTextPreview('hello', maxLength: 0), '');
      expect(plainTextPreview('hello', maxLength: -1), '');
      expect(plainTextPreview('hello', maxLength: 4), 'h...');
    });

    test('never cuts an emoji in half when truncating', () {
      // The emoji sits exactly at the cut point (character 77).
      final text = '${'a' * 76}😀${'b' * 10}';

      final result = plainTextPreview(text);

      // The old substring(0, 77) kept only half of the emoji, shown as "�".
      expect(result, '${'a' * 76}😀...');
    });

    test('keeps skin-tone and joined emoji whole at the cut point', () {
      expect(
        plainTextPreview('${'a' * 76}👍🏽 more text here'),
        '${'a' * 76}👍🏽...',
      );
      expect(
        plainTextPreview('${'a' * 76}👨‍👩‍👧 more text here'),
        '${'a' * 76}👨‍👩‍👧...',
      );
    });
  });
}
