import 'package:zedu/core/core.dart';

/// "Here's the link to your meeting", shown after creating one for later.
class BuzzMeetingLinkDialog extends StatefulWidget {
  const BuzzMeetingLinkDialog({super.key, required this.link});

  final String link;

  static Future<void> show(BuildContext context, String link) =>
      showDialog<void>(
        context: context,
        builder: (_) => BuzzMeetingLinkDialog(link: link),
      );

  @override
  State<BuzzMeetingLinkDialog> createState() => _BuzzMeetingLinkDialogState();
}

class _BuzzMeetingLinkDialogState extends State<BuzzMeetingLinkDialog> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.link));
    if (!mounted) return;
    setState(() => _copied = true);
    AppToastService.show(
      context,
      type: AppToastType.success,
      message: 'Link copied to clipboard',
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Dialog(
      backgroundColor: colors.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "Here's the link to your meeting",
                      style: context.textTheme.titleMedium?.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: Icon(Icons.close, size: 20, color: colors.textHint),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Copy this link and send it to people you want to meet with. '
                'Be sure to save it so you can use it later, too.',
                style: context.textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                decoration: BoxDecoration(
                  color: colors.background,
                  border: Border.all(color: colors.divider),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        widget.link,
                        style: context.textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy meeting link',
                      onPressed: _copy,
                      icon: Icon(
                        _copied ? Icons.check : Icons.copy_outlined,
                        size: 18,
                        color: _copied ? colors.success : colors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
