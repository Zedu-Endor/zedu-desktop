import 'package:zedu/features/features.dart';

/// How the desktop app can show a file's contents.
enum FilePreviewKind {
  image,
  svg,
  text,

  /// Not previewable; the person can download the file instead.
  none;

  /// The largest file of this kind that is fetched for a preview, in bytes.
  int get maxBytes => switch (this) {
    FilePreviewKind.image || FilePreviewKind.svg => 25 * 1024 * 1024,
    FilePreviewKind.text => 2 * 1024 * 1024,
    FilePreviewKind.none => 0,
  };

  static const _images = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'};
  static const _texts = {
    'txt', 'md', 'markdown', 'csv', 'tsv', 'json', 'log', 'xml', 'yaml', //
    'yml', 'html', 'htm', 'css', 'js', 'ts', 'dart', 'py', 'java', 'kt', //
    'go', 'rb', 'php', 'c', 'h', 'cpp', 'cs', 'swift', 'rs', 'sql', 'sh', //
    'ini', 'toml', 'conf', 'srt', 'vtt',
  };

  static FilePreviewKind of(WorkspaceFile file) {
    final type = file.fileType.toLowerCase();
    final mime = file.mimeType.toLowerCase();
    if (type == 'svg' || mime == 'image/svg+xml') return FilePreviewKind.svg;
    if (_images.contains(type) || (mime.startsWith('image/') && type.isEmpty)) {
      return FilePreviewKind.image;
    }
    if (_texts.contains(type) ||
        mime.startsWith('text/') ||
        mime == 'application/json') {
      return FilePreviewKind.text;
    }
    return FilePreviewKind.none;
  }
}
