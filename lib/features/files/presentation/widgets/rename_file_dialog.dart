import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// "Rename file": edits a file's name, then saves it. Keeping the same name
/// just closes the dialog. A failure keeps it open with the reason.
class RenameFileDialog extends ConsumerStatefulWidget {
  const RenameFileDialog({super.key, required this.file});

  final WorkspaceFile file;

  /// Shows the dialog. Returns the new name when the file was renamed.
  static Future<String?> show(
    BuildContext context, {
    required WorkspaceFile file,
  }) => showDialog<String>(
    context: context,
    builder: (_) => RenameFileDialog(file: file),
  );

  @override
  ConsumerState<RenameFileDialog> createState() => _RenameFileDialogState();
}

class _RenameFileDialogState extends ConsumerState<RenameFileDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    final name = widget.file.name;
    // Select the name without its extension, so typing keeps `.pdf`.
    final dot = name.lastIndexOf('.');
    _controller = TextEditingController(text: name)
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: dot > 0 ? dot : name.length,
      );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _rename() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a file name.');
      return;
    }
    if (name == widget.file.name) {
      Navigator.of(context).pop();
      return;
    }
    final error = await ref
        .read(fileRenamesProvider.notifier)
        .rename(widget.file, name);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(name);
    } else {
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isRenaming = ref.watch(
      fileRenamesProvider.select((ids) => ids.contains(widget.file.id)),
    );
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: color),
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
                'Rename file',
                style: context.textTheme.titleMedium?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                autofocus: true,
                enabled: !isRenaming,
                maxLength: 255,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _rename(),
                style: context.textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  color: colors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: 'File name',
                  counterText: '',
                  errorText: _error,
                  errorMaxLines: 3,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  enabledBorder: border(colors.divider),
                  focusedBorder: border(colors.primary),
                  errorBorder: border(colors.error),
                  focusedErrorBorder: border(colors.error),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: isRenaming
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ValueListenableBuilder(
                    valueListenable: _controller,
                    builder: (context, value, _) => FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                      ),
                      onPressed: isRenaming || value.text.trim().isEmpty
                          ? null
                          : _rename,
                      child: Text(isRenaming ? 'Renaming…' : 'Rename'),
                    ),
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
