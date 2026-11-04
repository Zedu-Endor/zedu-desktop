import 'package:zedu/core/core.dart';

class RichTextController extends TextEditingController {
  RichTextController({super.text});

  static final _boldRegex = RegExp(r'\*\*(.*?)\*\*', dotAll: true);
  static final _italicRegex = RegExp(r'(?<!\*)\*(.*?)\*(?!\*)', dotAll: true);
  static final _strikeRegex = RegExp(r'~~(.*?)~~', dotAll: true);
  static final _codeRegex = RegExp(r'`(.*?)`', dotAll: true);

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final defaultStyle = style ?? const TextStyle();
    final textStr = text;
    if (textStr.isEmpty) return TextSpan(style: defaultStyle, text: '');

    final allPatterns = [_boldRegex, _italicRegex, _strikeRegex, _codeRegex];

    final combined = RegExp(
      allPatterns.map((r) => r.pattern).join('|'),
      dotAll: true,
    );

    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in combined.allMatches(textStr)) {
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: textStr.substring(lastEnd, match.start),
            style: defaultStyle,
          ),
        );
      }

      final raw = match.group(0)!;

      // Each alternative has one capture: style only the outer token that
      // matched, without interpreting formatting markers inside inline code.
      if (match.group(1) != null) {
        final inner = match.group(1)!;
        spans.add(
          TextSpan(
            children: [
              TextSpan(
                text: '**',
                style: defaultStyle.copyWith(
                  color: Colors.transparent,
                  fontSize: 0.01,
                ),
              ),
              TextSpan(
                text: inner,
                style: defaultStyle.copyWith(fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text: '**',
                style: defaultStyle.copyWith(
                  color: Colors.transparent,
                  fontSize: 0.01,
                ),
              ),
            ],
          ),
        );
      } else if (match.group(3) != null) {
        final inner = match.group(3)!;
        spans.add(
          TextSpan(
            children: [
              TextSpan(
                text: '~~',
                style: defaultStyle.copyWith(
                  color: Colors.transparent,
                  fontSize: 0.01,
                ),
              ),
              TextSpan(
                text: inner,
                style: defaultStyle.copyWith(
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              TextSpan(
                text: '~~',
                style: defaultStyle.copyWith(
                  color: Colors.transparent,
                  fontSize: 0.01,
                ),
              ),
            ],
          ),
        );
      } else if (match.group(4) != null) {
        final inner = match.group(4)!;
        spans.add(
          TextSpan(
            children: [
              TextSpan(
                text: '`',
                style: defaultStyle.copyWith(
                  color: Colors.transparent,
                  fontSize: 0.01,
                ),
              ),
              TextSpan(
                text: inner,
                style: defaultStyle.copyWith(
                  fontFamily: 'monospace',
                  backgroundColor: const Color(0x1A6458F5),
                  color: const Color(0xFF6458F5),
                ),
              ),
              TextSpan(
                text: '`',
                style: defaultStyle.copyWith(
                  color: Colors.transparent,
                  fontSize: 0.01,
                ),
              ),
            ],
          ),
        );
      } else if (match.group(2) != null) {
        final inner = match.group(2)!;
        spans.add(
          TextSpan(
            children: [
              TextSpan(
                text: '*',
                style: defaultStyle.copyWith(
                  color: Colors.transparent,
                  fontSize: 0.01,
                ),
              ),
              TextSpan(
                text: inner,
                style: defaultStyle.copyWith(fontStyle: FontStyle.italic),
              ),
              TextSpan(
                text: '*',
                style: defaultStyle.copyWith(
                  color: Colors.transparent,
                  fontSize: 0.01,
                ),
              ),
            ],
          ),
        );
      } else {
        spans.add(TextSpan(text: raw, style: defaultStyle));
      }

      lastEnd = match.end;
    }

    if (lastEnd < textStr.length) {
      spans.add(
        TextSpan(text: textStr.substring(lastEnd), style: defaultStyle),
      );
    }

    return TextSpan(style: defaultStyle, children: spans);
  }
}
