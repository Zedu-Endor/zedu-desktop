import 'dart:io' show File;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:zedu/features/features.dart';

/// Writes a transcript to the file name the platform save dialog returns, or
/// null when the user cancels. Injected in tests so they never reach the
/// platform channel.
typedef TranscriptSaver =
    Future<String?> Function({
      required String fileName,
      required String contents,
    });

/// "Export transcript" for a DM: saves every loaded page of the conversation
/// as a plain text or Markdown file.
class ExportTranscriptDialog extends StatefulWidget {
  const ExportTranscriptDialog({
    super.key,
    required this.conversationName,
    required this.history,
    this.now,
    this.save,
  });

  final String conversationName;
  final ChatHistoryNotifier history;

  /// Fixed clock for tests; defaults to [DateTime.now].
  final DateTime Function()? now;
  final TranscriptSaver? save;

  @override
  State<ExportTranscriptDialog> createState() => _ExportTranscriptDialogState();
}

class _ExportTranscriptDialogState extends State<ExportTranscriptDialog> {
  TranscriptFormat _format = TranscriptFormat.plainText;
  bool _loadingOlder = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    widget.history.addListener(_onHistory);
    widget.history.loadAll().whenComplete(() {
      if (mounted) setState(() => _loadingOlder = false);
    });
  }

  @override
  void dispose() {
    widget.history.removeListener(_onHistory);
    super.dispose();
  }

  void _onHistory() {
    if (mounted) setState(() {});
  }

  List<TranscriptMessage> get _messages {
    final history = widget.history;
    final messages = <TranscriptMessage>[];
    for (final message in history.messages) {
      final media = (message['media'] as List<dynamic>?) ?? const [];
      final attachments = media
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (file) => TranscriptAttachment(
              name: (file['file_name'] ?? 'Attachment').toString(),
              link: (file['file_link'] ?? '').toString(),
            ),
          )
          .toList();
      final content = htmlMessageToMarkdown(
        message['content'] as String? ?? '',
      );
      if (content.trim().isEmpty && attachments.isEmpty) continue;
      messages.add(
        TranscriptMessage(
          sender: history.isMyMessage(message)
              ? history.currentUserName
              : widget.conversationName,
          sentAt:
              DateTime.tryParse(
                message['created_at']?.toString() ?? '',
              )?.toLocal() ??
              DateTime.now(),
          content: content,
          attachments: attachments,
        ),
      );
    }
    return messages;
  }

  Future<String?> _saveToDisk({
    required String fileName,
    required String contents,
  }) async {
    final path = await FilePicker.saveFile(
      dialogTitle: 'Save transcript',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: [_format.fileType],
      lockParentWindow: true,
    );
    if (path == null) return null;
    await File(path).writeAsString(contents);
    return path;
  }

  Future<void> _export(List<TranscriptMessage> messages) async {
    final now = widget.now?.call() ?? DateTime.now();
    final contents = formatTranscript(
      conversationName: widget.conversationName,
      messages: messages,
      format: _format,
      exportedAt: now,
    );
    final fileName = transcriptFileName(widget.conversationName, _format, now);
    setState(() => _saving = true);
    String? path;
    try {
      path = await (widget.save ?? _saveToDisk)(
        fileName: fileName,
        contents: contents,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (path != null && mounted) Navigator.of(context).pop(path);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final messages = _messages;
    final countLine = messages.length == 1
        ? '1 message'
        : '${messages.length} messages';

    return AlertDialog(
      title: const Text('Export transcript'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Save the conversation with ${widget.conversationName} to a '
              'file you can keep.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (_loadingOlder)
              Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text('Loading messages…', style: theme.textTheme.bodySmall),
                ],
              )
            else
              Text(
                '$countLine will be exported.',
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 4),
            RadioGroup<TranscriptFormat>(
              groupValue: _format,
              onChanged: (format) {
                if (format == null || _saving) return;
                setState(() => _format = format);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final format in TranscriptFormat.values)
                    RadioListTile<TranscriptFormat>(
                      value: format,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('${format.label} (${format.extension})'),
                      subtitle: Text(
                        format == TranscriptFormat.plainText
                            ? 'Readable in any text editor.'
                            : 'Keeps bold, lists and links.',
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _loadingOlder || _saving ? null : () => _export(messages),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Export'),
        ),
      ],
    );
  }
}
