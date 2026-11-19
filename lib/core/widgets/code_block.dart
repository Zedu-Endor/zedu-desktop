import 'dart:async';

import 'package:zedu/core/core.dart';

/// Matches a closed fenced block: the info string after the opening fence and
/// everything up to the closing fence. An unclosed fence is left as text.
final _fencedBlockPattern = RegExp(r'```([^\n]*)\n(.*?)```', dotAll: true);

/// One chunk of a message: either Markdown [text] or a fenced [code] block.
class MarkdownChunk {
  const MarkdownChunk.text(this.text) : code = null, language = null;

  const MarkdownChunk.code(this.code, this.language) : text = null;

  final String? text;
  final String? code;
  final String? language;

  bool get isCode => code != null;
}

/// Splits [source] around closed fenced code blocks, in order. Text between
/// blocks stays Markdown; each block keeps its exact code and info string.
List<MarkdownChunk> splitMarkdownChunks(String source) {
  final chunks = <MarkdownChunk>[];
  var last = 0;
  for (final match in _fencedBlockPattern.allMatches(source)) {
    if (match.start > last) {
      chunks.add(MarkdownChunk.text(source.substring(last, match.start)));
    }
    final language = match.group(1)!.trim();
    chunks.add(
      MarkdownChunk.code(
        match.group(2) ?? '',
        language.isEmpty ? null : language,
      ),
    );
    last = match.end;
  }
  if (last < source.length) {
    chunks.add(MarkdownChunk.text(source.substring(last)));
  }
  return chunks;
}

/// Markdown text where fenced code blocks render as [CodeBlock]s with working
/// copy buttons, instead of flutter_markdown's plain `pre` output.
///
/// Messages without fences render exactly as a plain [MarkdownBody] does.
class MarkdownWithCodeBlocks extends StatelessWidget {
  const MarkdownWithCodeBlocks({
    super.key,
    required this.data,
    required this.styleSheet,
    this.onTapLink,
  });

  final String data;
  final MarkdownStyleSheet styleSheet;

  /// Called with the link target when a Markdown link is tapped.
  final ValueChanged<String?>? onTapLink;

  MarkdownBody _body(String text) => MarkdownBody(
    data: text,
    styleSheet: styleSheet,
    onTapLink: onTapLink == null ? null : (_, href, _) => onTapLink!(href),
  );

  @override
  Widget build(BuildContext context) {
    final chunks = splitMarkdownChunks(data);
    if (chunks.length == 1 && !chunks.single.isCode) {
      return _body(data);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final chunk in chunks)
          if (chunk.isCode)
            CodeBlock(code: chunk.code!, language: chunk.language)
          else if (chunk.text!.trim().isNotEmpty)
            _body(chunk.text!),
      ],
    );
  }
}

/// A fenced code block with a copy button, as rendered inside chat messages.
///
/// The button copies [code] itself to the clipboard, so pasting documentation
/// into a message keeps a working copy action on its code blocks.
class CodeBlock extends StatefulWidget {
  const CodeBlock({super.key, required this.code, this.language});

  /// The code to show and to copy. Never blank for a rendered block.
  final String code;

  /// The `dart` in ```` ```dart ````, shown as a label when known.
  final String? language;

  @override
  State<CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<CodeBlock> {
  bool _copied = false;
  Timer? _resetTimer;
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _resetTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    _resetTimer?.cancel();
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    _resetTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border.all(color: colors.divider),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
                  child: Text(
                    widget.language ?? 'code',
                    style: TextStyle(fontSize: 11, color: colors.textHint),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copy code block',
                visualDensity: VisualDensity.compact,
                onPressed: _copy,
                icon: Icon(
                  _copied ? Icons.check : Icons.copy_outlined,
                  size: 16,
                  color: _copied ? colors.primary : colors.textHint,
                ),
              ),
            ],
          ),
          Divider(height: 1, color: colors.divider),
          Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                widget.code,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: colors.textPrimary,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
