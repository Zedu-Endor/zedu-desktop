import 'dart:convert';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Shows a file's contents in the app, as the web app's preview modal does:
/// images and SVGs (zoomable) and text files. Other files, files too large to
/// preview and failures say so, with Download and Open in browser.
class FilePreviewDialog extends ConsumerStatefulWidget {
  const FilePreviewDialog({
    super.key,
    required this.file,
    required this.onDownload,
    required this.onOpenExternally,
  });

  final WorkspaceFile file;

  /// Downloads the file; the dialog closes first.
  final VoidCallback onDownload;

  /// Opens the file outside the app, in the browser or its own app.
  final VoidCallback onOpenExternally;

  static Future<void> show(
    BuildContext context, {
    required WorkspaceFile file,
    required VoidCallback onDownload,
    required VoidCallback onOpenExternally,
  }) => showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => FilePreviewDialog(
      file: file,
      onDownload: onDownload,
      onOpenExternally: onOpenExternally,
    ),
  );

  @override
  ConsumerState<FilePreviewDialog> createState() => _FilePreviewDialogState();
}

class _FilePreviewDialogState extends ConsumerState<FilePreviewDialog> {
  late final FilePreviewKind _kind = FilePreviewKind.of(widget.file);
  Future<Result<Uint8List>>? _contents;
  final _imageZoom = TransformationController();

  static const _minZoom = 0.5;
  static const _maxZoom = 4.0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _imageZoom.dispose();
    super.dispose();
  }

  void _load() {
    if (_kind == FilePreviewKind.none) return;
    setState(() {
      _contents = ref
          .read(filesRepositoryProvider)
          .fetchFilePreview(widget.file, _kind);
    });
  }

  void _close() => Navigator.of(context).pop();

  void _download() {
    _close();
    widget.onDownload();
  }

  void _openExternally() {
    _close();
    widget.onOpenExternally();
  }

  double get _imageScale => _imageZoom.value.getMaxScaleOnAxis();

  void _zoomImage(double scale) {
    final s = scale.clamp(_minZoom, _maxZoom);
    _imageZoom.value = Matrix4.diagonal3Values(s, s, 1);
  }

  void _zoom({required bool zoomIn}) =>
      _zoomImage(_imageScale + (zoomIn ? 0.25 : -0.25));

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final size = MediaQuery.sizeOf(context);
    final canZoom =
        _kind == FilePreviewKind.image || _kind == FilePreviewKind.svg;

    return Dialog(
      backgroundColor: colors.onPrimary,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: size.width * 0.9,
        height: size.height * 0.9,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              file: widget.file,
              zoom: canZoom ? _ZoomControls(this) : null,
              onDownload: _download,
              onOpenExternally: _openExternally,
              onClose: _close,
            ),
            Divider(height: 1, color: colors.divider),
            Expanded(
              child: ColoredBox(color: colors.primaryBg, child: _body()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    final type = widget.file.fileType;
    if (_kind == FilePreviewKind.none) {
      return _PreviewMessage(
        title: 'No preview available',
        body: type.isEmpty
            ? 'This file can’t be previewed in the app. '
                  'Download it or open it in your browser.'
            : 'Preview isn’t available for .$type files. '
                  'Download it or open it in your browser.',
        onDownload: _download,
        onOpenExternally: _openExternally,
      );
    }
    return FutureBuilder<Result<Uint8List>>(
      future: _contents,
      builder: (context, snapshot) {
        final result = snapshot.data;
        if (result == null) {
          return Center(
            child: CircularProgressIndicator(color: context.colors.primary),
          );
        }
        return switch (result) {
          Failure(:final error) => _PreviewMessage(
            title: 'Could not load the preview',
            body: switch (error.kind) {
              ApiFailureKind.client => '${error.message} Download it instead.',
              ApiFailureKind.unknown ||
              ApiFailureKind.parsing => 'Please try again.',
              _ => error.friendlyMessage,
            },
            onRetry: error.kind == ApiFailureKind.client ? null : _load,
            onDownload: _download,
          ),
          Success(:final value) => _preview(value),
        };
      },
    );
  }

  Widget _preview(Uint8List bytes) {
    Widget broken() => _PreviewMessage(
      title: 'No preview available',
      body:
          'This file can’t be shown. '
          'Download it or open it in your browser.',
      onDownload: _download,
      onOpenExternally: _openExternally,
    );
    Widget zoomable(Widget child) => InteractiveViewer(
      transformationController: _imageZoom,
      minScale: _minZoom,
      maxScale: _maxZoom,
      boundaryMargin: const EdgeInsets.all(200),
      child: Center(child: child),
    );

    switch (_kind) {
      case FilePreviewKind.image:
        return zoomable(
          Image.memory(
            bytes,
            fit: BoxFit.contain,
            semanticLabel: widget.file.name,
            errorBuilder: (_, _, _) => broken(),
          ),
        );
      case FilePreviewKind.svg:
        return zoomable(
          SvgPicture.memory(
            bytes,
            fit: BoxFit.contain,
            semanticsLabel: widget.file.name,
            errorBuilder: (_, _, _) => broken(),
          ),
        );
      case FilePreviewKind.text:
        final text = _decodeText(bytes);
        // NUL characters mean a binary file with a text-like name.
        if (text == null || text.contains('\u0000')) return broken();
        return _TextPreview(text: text);
      case FilePreviewKind.none:
        return broken();
    }
  }

  String? _decodeText(Uint8List bytes) {
    if (bytes.length >= 2) {
      final littleEndian = bytes[0] == 0xff && bytes[1] == 0xfe;
      final bigEndian = bytes[0] == 0xfe && bytes[1] == 0xff;
      if (littleEndian || bigEndian) {
        // A UTF-16 BOM identifies text whose ASCII code units contain zero
        // bytes. Decode those units before applying the binary-file guard.
        if (bytes.length.isOdd) return null;
        final data = ByteData.sublistView(bytes);
        final endian = littleEndian ? Endian.little : Endian.big;
        return String.fromCharCodes([
          for (var offset = 2; offset < bytes.length; offset += 2)
            data.getUint16(offset, endian),
        ]);
      }
    }
    return utf8.decode(bytes, allowMalformed: true);
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.file,
    required this.zoom,
    required this.onDownload,
    required this.onOpenExternally,
    required this.onClose,
  });

  final WorkspaceFile file;
  final Widget? zoom;
  final VoidCallback onDownload;
  final VoidCallback onOpenExternally;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = file.fileType.toUpperCase();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      child: Row(
        children: [
          if (type.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: colors.primaryBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                type,
                style: context.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  formatFileSize(file.size),
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (zoom != null) ...[zoom!, const SizedBox(width: 12)],
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
            ),
            onPressed: onDownload,
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('Download'),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Open in browser',
            onPressed: onOpenExternally,
            icon: Icon(Icons.open_in_new, color: colors.textSecondary),
          ),
          IconButton(
            tooltip: 'Close preview (Esc)',
            onPressed: onClose,
            icon: Icon(Icons.close, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Zoom out, the zoom level, zoom in and fit.
class _ZoomControls extends StatelessWidget {
  const _ZoomControls(this.state);

  final _FilePreviewDialogState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget button(String tooltip, IconData icon, VoidCallback onPressed) =>
        IconButton(
          tooltip: tooltip,
          visualDensity: VisualDensity.compact,
          onPressed: onPressed,
          icon: Icon(icon, size: 20, color: colors.textSecondary),
        );

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.divider),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button('Zoom out', Icons.zoom_out, () => state._zoom(zoomIn: false)),
          ValueListenableBuilder(
            valueListenable: state._imageZoom,
            builder: (context, _, _) => SizedBox(
              width: 48,
              child: Text(
                '${(state._imageScale * 100).round()}%',
                textAlign: TextAlign.center,
                style: context.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ),
          button('Zoom in', Icons.zoom_in, () => state._zoom(zoomIn: true)),
          button(
            'Fit to window',
            Icons.fit_screen_outlined,
            () => state._zoomImage(1),
          ),
        ],
      ),
    );
  }
}

class _TextPreview extends StatelessWidget {
  const _TextPreview({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.onPrimary,
        border: Border.all(color: colors.divider),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Scrollbar(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            text.isEmpty ? '(This file is empty.)' : text,
            style: context.textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.5,
              color: colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewMessage extends StatelessWidget {
  const _PreviewMessage({
    required this.title,
    required this.body,
    required this.onDownload,
    this.onOpenExternally,
    this.onRetry,
  });

  final String title;
  final String body;
  final VoidCallback onDownload;
  final VoidCallback? onOpenExternally;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.insert_drive_file_outlined,
                size: 48,
                color: colors.textSecondary,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                textAlign: TextAlign.center,
                style: context.textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (onRetry != null)
                    TextButton(onPressed: onRetry, child: const Text('Retry')),
                  OutlinedButton.icon(
                    onPressed: onDownload,
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text('Download'),
                  ),
                  if (onOpenExternally != null)
                    TextButton.icon(
                      onPressed: onOpenExternally,
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Open in browser'),
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
