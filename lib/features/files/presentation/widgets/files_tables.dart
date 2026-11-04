import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// `Nov 1, 2026`, or `—` when there is no date.
String formatFileDate(DateTime? date) =>
    date == null ? '—' : '${_months[date.month - 1]} ${date.day}, ${date.year}';

/// `512 B`, `1.5 KB`, `12 MB`, …
String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var size = bytes / 1024;
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  final text = size >= 10 || size == size.roundToDouble()
      ? size.round().toString()
      : size.toStringAsFixed(1);
  return '$text ${units[unit]}';
}

String formatItemCount(int count) => count == 1 ? '1 item' : '$count items';

/// Below this width the Owner and Shared in columns are hidden.
const _compactWidth = 720.0;

class _Column {
  const _Column(this.label, this.flex, {this.compact = true});

  final String label;
  final int flex;

  /// Whether the column stays when the table is narrow.
  final bool compact;
}

class _Table extends StatelessWidget {
  const _Table({
    required this.columns,
    required this.rowCount,
    required this.cellsOf,
    this.onTapRow,
  });

  final List<_Column> columns;
  final int rowCount;
  final List<Widget> Function(int row) cellsOf;
  final ValueChanged<int>? onTapRow;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < _compactWidth;
        final shown = [
          for (var i = 0; i < columns.length; i++)
            if (!isCompact || columns[i].compact) i,
        ];

        Widget row(List<Widget> cells, {bool header = false}) => Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 20,
            vertical: header ? 12 : 14,
          ),
          child: Row(
            children: [
              for (final i in shown)
                Expanded(flex: columns[i].flex, child: cells[i]),
            ],
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.background,
                border: Border(bottom: BorderSide(color: colors.divider)),
              ),
              child: row(header: true, [
                for (final column in columns)
                  Text(
                    column.label,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
              ]),
            ),
            for (var r = 0; r < rowCount; r++)
              Material(
                color: colors.onPrimary,
                child: InkWell(
                  onTap: onTapRow == null ? null : () => onTapRow!(r),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: colors.divider)),
                    ),
                    child: row(cellsOf(r)),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

Widget _cellText(BuildContext context, String text) => Text(
  text,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  style: context.textTheme.bodyMedium?.copyWith(
    fontSize: 13,
    color: context.colors.textPrimary,
  ),
);

Widget _nameCell(BuildContext context, Widget icon, String name) => Row(
  children: [
    icon,
    const SizedBox(width: 14),
    Expanded(
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.textTheme.titleSmall?.copyWith(
          color: context.colors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
  ],
);

class FoldersTable extends StatelessWidget {
  const FoldersTable({
    super.key,
    required this.folders,
    required this.ownerNameOf,
    required this.onOpen,
  });

  final List<FileFolder> folders;
  final String Function(String userId) ownerNameOf;
  final ValueChanged<FileFolder> onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return _Table(
      columns: const [
        _Column('Name', 5),
        _Column('Owner', 2, compact: false),
        _Column('Date Created', 2),
        _Column('Items', 1),
      ],
      rowCount: folders.length,
      onTapRow: (r) => onOpen(folders[r]),
      cellsOf: (r) {
        final folder = folders[r];
        return [
          _nameCell(
            context,
            Icon(Icons.folder, color: colors.primary, size: 22),
            folder.name,
          ),
          _cellText(context, ownerNameOf(folder.userId)),
          _cellText(context, formatFileDate(folder.createdAt)),
          _cellText(context, formatItemCount(folder.itemCount)),
        ];
      },
    );
  }
}

class FilesTable extends StatelessWidget {
  const FilesTable({
    super.key,
    required this.files,
    required this.ownerNameOf,
    required this.onOpen,
    this.onDownload,
    this.onRename,
    this.onDelete,
    this.deletesPermanently = false,
    this.downloads = const {},
  });

  final List<WorkspaceFile> files;
  final String Function(WorkspaceFile file) ownerNameOf;
  final ValueChanged<WorkspaceFile> onOpen;

  /// Downloads a file. When null, as in Deleted files, the menu has no
  /// Download.
  final ValueChanged<WorkspaceFile>? onDownload;

  /// Renames a file. When null, as in Deleted files, the menu has no Rename.
  final ValueChanged<WorkspaceFile>? onRename;

  /// Deletes a file. When null, the menu has no Delete.
  final ValueChanged<WorkspaceFile>? onDelete;

  /// Whether Delete removes files for good, as in Deleted files. The menu then
  /// says Delete permanently.
  final bool deletesPermanently;

  /// Downloads in progress, by file id: the share downloaded, or null while
  /// the size is unknown.
  final Map<String, double?> downloads;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final download = onDownload;
    final rename = onRename;
    final delete = onDelete;
    final hasActions = download != null || rename != null || delete != null;

    return _Table(
      columns: [
        const _Column('Name', 5),
        const _Column('Shared in', 2, compact: false),
        const _Column('Owner', 2, compact: false),
        const _Column('Date Modified', 2),
        const _Column('Size', 1),
        if (hasActions) const _Column('', 1),
      ],
      rowCount: files.length,
      onTapRow: (r) => onOpen(files[r]),
      cellsOf: (r) {
        final file = files[r];
        return [
          _nameCell(
            context,
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colors.primaryBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                file.isImage
                    ? Icons.image_outlined
                    : Icons.insert_drive_file_outlined,
                color: colors.primary,
                size: 18,
              ),
            ),
            file.name,
          ),
          _cellText(context, file.sharedIn.isEmpty ? '—' : file.sharedIn),
          _cellText(context, ownerNameOf(file)),
          _cellText(context, formatFileDate(file.modifiedAt)),
          _cellText(context, formatFileSize(file.size)),
          if (hasActions)
            Align(
              alignment: Alignment.centerRight,
              child: _FileActionsMenu(
                fileName: file.name,
                isDownloading: downloads.containsKey(file.id),
                progress: downloads[file.id],
                onDownload: download == null ? null : () => download(file),
                onRename: rename == null ? null : () => rename(file),
                onDelete: delete == null ? null : () => delete(file),
                deleteLabel: deletesPermanently
                    ? 'Delete permanently'
                    : 'Delete',
              ),
            ),
        ];
      },
    );
  }
}

enum _FileAction { download, rename, delete }

/// The ⋮ menu of a file row, holding the actions on that file. While the file
/// downloads it shows a progress ring instead.
class _FileActionsMenu extends StatelessWidget {
  const _FileActionsMenu({
    required this.fileName,
    required this.isDownloading,
    required this.progress,
    required this.onDownload,
    required this.onRename,
    required this.onDelete,
    required this.deleteLabel,
  });

  final String fileName;
  final bool isDownloading;
  final double? progress;
  final VoidCallback? onDownload;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;
  final String deleteLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (isDownloading) {
      final percent = progress == null ? '' : ' ${(progress! * 100).round()}%';
      return Tooltip(
        message: 'Downloading$percent',
        child: SizedBox.square(
          dimension: 32,
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 2,
              color: colors.primary,
              backgroundColor: colors.divider,
            ),
          ),
        ),
      );
    }

    PopupMenuItem<_FileAction> item(
      _FileAction value,
      IconData icon,
      String label, {
      bool destructive = false,
    }) => PopupMenuItem(
      value: value,
      height: 40,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: destructive ? colors.error : colors.textSecondary,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: context.textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              color: destructive ? colors.error : colors.textPrimary,
            ),
          ),
        ],
      ),
    );

    return PopupMenuButton<_FileAction>(
      tooltip: 'More actions for $fileName',
      position: PopupMenuPosition.under,
      color: colors.onPrimary,
      padding: EdgeInsets.zero,
      iconSize: 20,
      constraints: const BoxConstraints(minWidth: 160),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(32),
        minimumSize: const Size.square(32),
        padding: EdgeInsets.zero,
      ),
      icon: Icon(Icons.more_vert, color: colors.textSecondary),
      onSelected: (action) => switch (action) {
        _FileAction.download => onDownload?.call(),
        _FileAction.rename => onRename?.call(),
        _FileAction.delete => onDelete?.call(),
      },
      itemBuilder: (context) => [
        if (onDownload != null)
          item(_FileAction.download, Icons.download_outlined, 'Download'),
        if (onRename != null)
          item(_FileAction.rename, Icons.drive_file_rename_outline, 'Rename'),
        if (onDelete != null)
          item(
            _FileAction.delete,
            Icons.delete_outline,
            deleteLabel,
            destructive: true,
          ),
      ],
    );
  }
}
