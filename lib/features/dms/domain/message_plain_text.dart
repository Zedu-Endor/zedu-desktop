/// Rendering message content as the text a person actually wrote.
///
/// Messages sent from web or mobile arrive as HTML (`<p>Hello&nbsp;you</p>`),
/// and some of it is escaped twice (`&amp;nbsp;`), so a preview that only
/// strips tags still shows entities. Text someone typed that merely looks like
/// a tag (`<ada@zedu.chat>`, `List<String>`) is not markup and stays as typed.
library;

final _tagPattern = RegExp(r'<(/?)([a-zA-Z][a-zA-Z0-9]*)\b[^>]*>');
final _entityPattern = RegExp(r'&(#[xX][0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);');

const _namedEntities = {
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': ' ',
};

/// Elements that never have a closing tag, so one occurrence is enough.
const _voidTags = {'br', 'hr', 'img', 'input', 'wbr'};

/// Tags that start or end a line of their own.
const _blockTags = {
  'p',
  'div',
  'blockquote',
  'pre',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'ul',
  'ol',
  'li',
  'table',
  'tr',
  'section',
  'article',
  'header',
  'footer',
};

/// Tags that only wrap other content, so they leave no trace of their own.
const _inlineTags = {
  'strong',
  'b',
  'em',
  'i',
  'u',
  's',
  'del',
  'strike',
  'code',
  'span',
  'a',
  'small',
  'sub',
  'sup',
};

bool _isKnownTag(String name) =>
    _voidTags.contains(name) ||
    _blockTags.contains(name) ||
    _inlineTags.contains(name);

/// Tag names in [content] that are markup rather than text: a void element
/// (`<br>`), or a name with both an opening and a closing tag. A lone `<div>`,
/// a generic type (`List<String>`) or an address (`<ada@zedu.chat>`) is what
/// the sender typed, so it stays text.
Set<String> _markupTagsIn(String content) {
  final openings = <String>{};
  final closings = <String>{};
  for (final match in _tagPattern.allMatches(content)) {
    final name = match.group(2)!.toLowerCase();
    if (!_isKnownTag(name)) continue;
    if (match.group(1) == '/') {
      closings.add(name);
    } else {
      openings.add(name);
    }
  }
  return {
    ...openings.where(closings.contains),
    ..._voidTags.where(openings.contains),
  };
}

/// Turns message HTML into readable plain text: tags become line breaks where
/// they mark a new line, entities are decoded (including content escaped
/// twice), and nothing is ever interpreted as HTML.
String htmlMessageToPlainText(String content) {
  final decoded = _decodeRepeatedly(content);
  final markup = _markupTagsIn(decoded);

  final out = StringBuffer();
  var index = 0;
  for (final match in _tagPattern.allMatches(decoded)) {
    final tag = match.group(2)!.toLowerCase();
    // Typed text that only looks like a tag: leave it for the text run.
    if (!markup.contains(tag)) continue;

    out.write(decoded.substring(index, match.start));
    index = match.end;
    if (tag == 'br' || _blockTags.contains(tag)) out.write('\n');
  }
  out.write(decoded.substring(index));

  return out
      .toString()
      .replaceAll(RegExp(r'[ \t\f\v]+'), ' ')
      .replaceAll(RegExp(r' *\n *'), '\n')
      .replaceAll(RegExp(r'\n{2,}'), '\n')
      .trim();
}

/// Decodes entities until decoding stops changing the text, so content escaped
/// twice (`&amp;nbsp;`) ends up as the space it stands for.
String _decodeRepeatedly(String text) {
  var current = text;
  for (var pass = 0; pass < 3; pass++) {
    final next = _decodeEntities(current);
    if (next == current) break;
    current = next;
  }
  return current;
}

String _decodeEntities(String text) {
  return text.replaceAllMapped(_entityPattern, (match) {
    final name = match.group(1)!;
    if (name.startsWith('#')) {
      final hex = name.length > 1 && (name[1] == 'x' || name[1] == 'X');
      final code = int.tryParse(
        name.substring(hex ? 2 : 1),
        radix: hex ? 16 : 10,
      );
      if (code == null || code > 0x10FFFF) return match.group(0)!;
      return String.fromCharCode(code);
    }
    return _namedEntities[name.toLowerCase()] ?? match.group(0)!;
  });
}
