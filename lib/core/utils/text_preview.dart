import 'package:zedu/core/core.dart';

/// Plain-text preview of a message, for places that can't render rich text
/// (e.g. desktop notifications).
///
/// Message content arrives as HTML from the web app (`<p>hey</p>`) or as
/// inline Markdown from desktop (`**bold**`, `_italic_`, `[docs](url)`), so
/// both are stripped. Truncation counts user-perceived characters (grapheme
/// clusters), so an emoji, including skin-tone and joined emoji, is never cut
/// apart.
String plainTextPreview(String content, {int maxLength = 80}) {
  var text = content.replaceAll(_lineBreak, ' ').replaceAll(_htmlTag, '');
  text = _decodeHtmlEntities(text);
  text = text
      .replaceAllMapped(_markdownLink, (match) => match[1]!)
      .replaceAllMapped(RegExp(r'(\*\*|~~|`|\*)(.+?)\1'), (match) => match[2]!)
      .replaceAllMapped(_underscoreEmphasis, (match) => match[2]!);
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

  final characters = text.characters;
  final limit = maxLength < 0 ? 0 : maxLength;
  if (characters.length <= limit) return text;
  // Too short for an ellipsis, so cut without one.
  if (limit <= 3) return characters.take(limit).string;
  return '${characters.take(limit - 3).string}...';
}

/// A `<br>` or `<li>` (with or without attributes, since `</li>` may be
/// omitted) or the end of a block element, which become a space so the words
/// on either side stay apart.
final _lineBreak = RegExp(
  r'''<(?:br|li)\b[^<>"']*(?:(?:"[^"]*"|'[^']*')[^<>"']*)*>'''
  r'''|</(p|div|li|h[1-6])\s*>''',
  caseSensitive: false,
);

/// An HTML tag: `<` followed by a tag name, so plain text such as `2 < 3 > 1`
/// is kept. Quoted attribute values may contain `>`.
final _htmlTag = RegExp(
  r'''</?[a-zA-Z][^<>"']*(?:(?:"[^"]*"|'[^']*')[^<>"']*)*>''',
);

/// `_emphasis_` / `__strong__`. The markers must not touch a word character
/// on the outside, so underscores inside words such as `snake_case` are kept.
final _underscoreEmphasis = RegExp(r'(?<!\w)(__|_)(\S(?:.*?\S)?)\1(?!\w)');

/// An inline Markdown link or image, `[label](url)` / `![alt](url)`.
final _markdownLink = RegExp(r'!?\[([^\]]*)\]\([^)\s]*\)');

/// A decimal or hexadecimal character reference, `&#128512;` / `&#x1F600;`.
final _numericEntity = RegExp(r'&#(?:[xX]([0-9a-fA-F]+)|([0-9]+));');

/// `&amp;` is decoded last so `&amp;lt;` becomes the text `&lt;`, not `<`.
String _decodeHtmlEntities(String text) => text
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAllMapped(_numericEntity, _decodeNumericEntity)
    .replaceAll('&amp;', '&');

/// Invalid code points (0, surrogates, beyond U+10FFFF) are left as typed.
String _decodeNumericEntity(Match match) {
  final hex = match[1];
  final code = hex != null
      ? int.tryParse(hex, radix: 16)
      : int.tryParse(match[2]!);
  if (code == null ||
      code == 0 ||
      code > 0x10FFFF ||
      (code >= 0xD800 && code <= 0xDFFF)) {
    return match[0]!;
  }
  return String.fromCharCode(code);
}
