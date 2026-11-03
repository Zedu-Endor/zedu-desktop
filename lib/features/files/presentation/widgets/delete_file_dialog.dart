import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// "Delete file?": confirms deleting a file, then deletes it. A failure keeps
/// the dialog open with the reason, and the file stays in the list.
class DeleteFileDialog extends ConsumerStatefulWidget {
  const DeleteFileDialog({
    super.key,
    required this.file,
    this.permanent = false,
  });

  final WorkspaceFile file;

  /// Removes the file for good, from Deleted files, instead of moving it
  /// there.
  final bool permanent;

  /// Shows the dialog. Returns true when the file was deleted.
  static Future<bool> show(
    BuildContext context, {
    required WorkspaceFile file,
    bool permanent = false,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (_) => DeleteFileDialog(file: file, permanent: permanent),
      ) ??
      false;

  @override
  ConsumerState<DeleteFileDialog> createState() => _DeleteFileDialogState();
}

class _DeleteFileDialogState extends ConsumerState<DeleteFileDialog> {
  String? _error;

  Future<void> _delete() async {
    setState(() => _error = null);
    final error = await ref
        .read(fileDeletionsProvider.notifier)
        .delete(widget.file, permanent: widget.permanent);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDeleting = ref.watch(
      fileDeletionsProvider.select((ids) => ids.contains(widget.file.id)),
    );
    final bodyStyle = context.textTheme.bodyMedium?.copyWith(
      fontSize: 13,
      color: colors.textSecondary,
    );

    return Dialog(
      backgroundColor: colors.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.permanent ? 'Delete file permanently?' : 'Delete file?',
                style: context.textTheme.titleMedium?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text.rich(
                TextSpan(
                  style: bodyStyle,
                  children: [
                    const TextSpan(text: 'This action will delete '),
                    TextSpan(
                      text: widget.file.name,
                      style: bodyStyle?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    TextSpan(
                      text: widget.permanent
                          ? ' for good. You can’t undo this.'
                          : '. It moves to Deleted files.',
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    color: colors.error,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: isDeleting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.error,
                      foregroundColor: colors.onPrimary,
                    ),
                    onPressed: isDeleting ? null : _delete,
                    child: Text(isDeleting ? 'Deleting…' : 'Delete'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
