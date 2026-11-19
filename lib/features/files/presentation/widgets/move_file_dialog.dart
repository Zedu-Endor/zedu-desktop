import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// "Move {file}": picks a folder and moves the file into it. A failure keeps
/// the dialog open with the reason.
///
/// It starts at the top-level folders. Opening a folder lists the folders
/// inside it, so a file can be moved into a subfolder at any depth, and the
/// breadcrumb goes back up.
class MoveFileDialog extends ConsumerStatefulWidget {
  const MoveFileDialog({super.key, required this.file});

  final WorkspaceFile file;

  /// Shows the dialog. Returns the folder the file was moved into.
  static Future<FileFolder?> show(
    BuildContext context, {
    required WorkspaceFile file,
  }) => showDialog<FileFolder>(
    context: context,
    builder: (_) => MoveFileDialog(file: file),
  );

  @override
  ConsumerState<MoveFileDialog> createState() => _MoveFileDialogState();
}

class _MoveFileDialogState extends ConsumerState<MoveFileDialog> {
  FileFolder? _selected;
  String? _error;

  /// The folders opened in the dialog, outermost first; empty at the top
  /// level.
  final _path = <FileFolder>[];

  String? get _parentId => _path.isEmpty ? null : _path.last.id;

  /// Shows the folders inside [folder]. A choice made at another level is
  /// cleared, so Move only ever moves into a folder that is on screen.
  void _open(FileFolder folder) => setState(() {
    _path.add(folder);
    _selected = null;
    _error = null;
  });

  /// Goes back to the level [depth] folders deep (0 is the top level).
  void _goUp(int depth) => setState(() {
    _path.removeRange(depth, _path.length);
    _selected = null;
    _error = null;
  });

  Future<void> _move() async {
    final folder = _selected;
    if (folder == null) return;
    setState(() => _error = null);
    final error = await ref
        .read(fileMovesProvider.notifier)
        .move(widget.file, folder);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(folder);
    } else {
      setState(() => _error = error);
    }
  }

  /// One folder: its radio picks it, and the arrow opens it. The folder the
  /// file is already in can't be picked, but it can be opened, so its
  /// subfolders are still reachable.
  Widget _folderTile(
    BuildContext context,
    FileFolder folder, {
    required bool isMoving,
  }) {
    final colors = context.colors;
    final isCurrent = folder.id == widget.file.folderId;
    return RadioListTile<String>(
      value: folder.id,
      enabled: !isCurrent,
      dense: true,
      contentPadding: EdgeInsets.zero,
      activeColor: colors.primary,
      title: Row(
        children: [
          Icon(Icons.folder, size: 20, color: colors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              folder.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                color: isCurrent ? colors.textSecondary : colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
      subtitle: isCurrent
          ? Text(
              'The file is already here',
              style: context.textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
              ),
            )
          : null,
      secondary: IconButton(
        tooltip: 'Open ${folder.name}',
        icon: Icon(Icons.chevron_right, color: colors.textSecondary),
        onPressed: isMoving ? null : () => _open(folder),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isMoving = ref.watch(
      fileMovesProvider.select((ids) => ids.contains(widget.file.id)),
    );
    final parentId = _parentId;
    final folders = ref.watch(moveTargetFoldersProvider(parentId));
    final textStyle = context.textTheme.bodyMedium?.copyWith(
      fontSize: 13,
      color: colors.textSecondary,
    );

    Widget message(String text, {VoidCallback? onRetry}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text(text, textAlign: TextAlign.center, style: textStyle),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );

    return Dialog(
      backgroundColor: colors.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Move ${widget.file.name}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.titleMedium?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text('Choose a folder to move it to.', style: textStyle),
              if (_path.isNotEmpty) ...[
                const SizedBox(height: 8),
                _Breadcrumb(path: _path, onGoUp: isMoving ? null : _goUp),
              ],
              const SizedBox(height: 12),
              Flexible(
                child: folders.when(
                  loading: () => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator(color: colors.primary),
                    ),
                  ),
                  error: (_, _) => message(
                    'Could not load folders.',
                    onRetry: () =>
                        ref.invalidate(moveTargetFoldersProvider(parentId)),
                  ),
                  data: (all) {
                    if (all.isEmpty) {
                      return message(
                        _path.isEmpty
                            ? 'No other folders yet. Create one first.'
                            : 'No folders inside ${_path.last.name}.',
                      );
                    }
                    return RadioGroup<String>(
                      groupValue: _selected?.id,
                      onChanged: (id) {
                        if (isMoving) return;
                        setState(() {
                          _selected = all.firstWhere((f) => f.id == id);
                          _error = null;
                        });
                      },
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final folder in all)
                            _folderTile(context, folder, isMoving: isMoving),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    color: colors.error,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: isMoving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                    ),
                    onPressed: isMoving || _selected == null ? null : _move,
                    child: Text(isMoving ? 'Moving…' : 'Move'),
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

/// "All folders > Design > Logos": every folder above the one shown goes
/// back to that level when tapped.
class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.path, required this.onGoUp});

  final List<FileFolder> path;

  /// Goes back to the level that many folders deep; null while moving.
  final void Function(int depth)? onGoUp;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = context.textTheme.bodyMedium?.copyWith(fontSize: 13);
    final names = ['All folders', for (final folder in path) folder.name];

    Widget crumb(int depth) {
      final isLast = depth == names.length - 1;
      if (isLast) {
        return Text(
          names[depth],
          overflow: TextOverflow.ellipsis,
          style: style?.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        );
      }
      final goUp = onGoUp;
      return InkWell(
        onTap: goUp == null ? null : () => goUp(depth),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Text(
            names[depth],
            style: style?.copyWith(color: colors.primary),
          ),
        ),
      );
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var depth = 0; depth < names.length; depth++) ...[
          if (depth > 0)
            Icon(Icons.chevron_right, size: 16, color: colors.textSecondary),
          crumb(depth),
        ],
      ],
    );
  }
}
