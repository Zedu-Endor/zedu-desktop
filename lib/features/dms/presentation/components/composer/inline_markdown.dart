import 'package:zedu/core/core.dart';

/// Inline Markdown used by DM messages: `*italic*`, `**bold**`,
/// `~~strike~~` and `` `code` ``.
///
/// Italic is tried first and may contain `**bold**` pairs, so text that was
/// made bold and italic (`***word***`, from either toolbar order) is read as
/// italic around bold instead of bold around a stray `*`. A lone `**` is the
/// empty italic the toolbar inserts with no selection; in a sent message it
/// stays visible as text. `\*` is an escaped, literal star.
final _inlineMarkdown = RegExp(
  r'\\(?<escaped>\*)'
  r'|(?<!\*)\*(?<italic>(?:\\\*|\*\*.+?\*\*|[^*])+?)(?<!\\)\*(?!\*)'
  r'|\*\*(?<bold>.*?)\*\*(?!\*)'
  r'|(?<!\*)\*\*(?!\*)'
  r'|~~(?<strike>.*?)~~'
  r'|`(?<code>.*?)`',
  dotAll: true,
);

/// Builds a span for [text] with inline Markdown applied on top of [style].
///
/// Formatting nests, so `~~**word**~~` is struck through and bold. Inline
/// code stays literal. With [keepMarkers] the markers stay in the span but
/// are invisible, so the span's text matches [text] (needed by the composer,
/// whose cursor offsets index into the raw text); otherwise they are dropped.
///
/// Each formatted token is one span whose children are its (hidden) opening
/// marker, its text and its closing marker. [plainText] builds the spans for
/// text outside inline code, for example to make links tappable.
TextSpan buildInlineMarkdownSpan(
  String text,
  TextStyle style, {
  bool keepMarkers = false,
  TextSpan Function(String text, TextStyle style)? plainText,
}) {
  if (text.isEmpty) return TextSpan(style: style, text: '');
  return TextSpan(
    style: style,
    children: _inlineSpans(
      text,
      style,
      keepMarkers,
      plainText ?? (text, style) => TextSpan(text: text, style: style),
    ),
  );
}

List<InlineSpan> _inlineSpans(
  String text,
  TextStyle style,
  bool keepMarkers,
  TextSpan Function(String text, TextStyle style) plainText,
) {
  final spans = <InlineSpan>[];
  final hiddenStyle = style.copyWith(color: Colors.transparent, fontSize: 0.01);

  void addToken(String marker, String inner, TextStyle innerStyle, bool nest) {
    final parts = <InlineSpan>[
      if (keepMarkers) TextSpan(text: marker, style: hiddenStyle),
    ];
    if (inner.isNotEmpty) {
      if (nest) {
        final nested = _inlineSpans(inner, innerStyle, keepMarkers, plainText);
        parts.add(
          nested.length == 1 ? nested.single : TextSpan(children: nested),
        );
      } else {
        parts.add(TextSpan(text: inner, style: innerStyle));
      }
    }
    if (keepMarkers) parts.add(TextSpan(text: marker, style: hiddenStyle));
    spans.add(TextSpan(children: parts));
  }

  var lastEnd = 0;
  for (final match in _inlineMarkdown.allMatches(text)) {
    if (match.start > lastEnd) {
      spans.add(plainText(text.substring(lastEnd, match.start), style));
    }

    final escaped = match.namedGroup('escaped');
    final italic = match.namedGroup('italic');
    final bold = match.namedGroup('bold');
    final strike = match.namedGroup('strike');
    final code = match.namedGroup('code');
    if (escaped != null) {
      // `\*` is a literal star: shown without the backslash in a sent
      // message, kept as typed in the composer (Ziki #2879).
      spans.add(plainText(keepMarkers ? match.group(0)! : escaped, style));
    } else if (italic != null) {
      addToken('*', italic, style.copyWith(fontStyle: FontStyle.italic), true);
    } else if (bold != null) {
      addToken('**', bold, style.copyWith(fontWeight: FontWeight.bold), true);
    } else if (strike != null) {
      addToken(
        '~~',
        strike,
        style.copyWith(decoration: TextDecoration.lineThrough),
        true,
      );
    } else if (code != null) {
      addToken(
        '`',
        code,
        style.copyWith(
          fontFamily: 'monospace',
          backgroundColor: const Color(0x1A6458F5),
          color: const Color(0xFF6458F5),
        ),
        false,
      );
    } else if (keepMarkers) {
      // Empty italic (`**`): nothing to show but the hidden markers.
      spans.add(TextSpan(text: match.group(0), style: hiddenStyle));
    } else {
      // A lone `**` in a sent message formats nothing, so it is text
      // (`2 ** 3`, `**/*.dart`) and stays visible (Ziki #2879).
      spans.add(plainText(match.group(0)!, style));
    }

    lastEnd = match.end;
  }

  if (lastEnd < text.length) {
    spans.add(plainText(text.substring(lastEnd), style));
  }
  return spans;
}
