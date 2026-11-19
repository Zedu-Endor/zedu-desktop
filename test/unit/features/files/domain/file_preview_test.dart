import 'package:zedu/features/features.dart';

import '../../../../helpers/helpers.dart';

void main() {
  test('image classification shares preview support including BMP and SVG', () {
    for (final type in ['bmp', 'BMP', 'svg', 'SVG', 'png', 'jpg', 'webp']) {
      final file = WorkspaceFile(
        id: type,
        name: 'picture.$type',
        fileType: type,
      );
      expect(file.isImage, isTrue, reason: type);
    }
    expect(
      const WorkspaceFile(
        id: 'svg',
        name: 'vector',
        mimeType: 'IMAGE/SVG+XML',
      ).isImage,
      isTrue,
    );
    expect(
      const WorkspaceFile(id: 'pdf', name: 'document', fileType: 'pdf').isImage,
      isFalse,
    );
    expect(
      const WorkspaceFile(id: 'txt', name: 'notes', fileType: 'txt').isImage,
      isFalse,
    );
  });
  FilePreviewKind kind(String name, {String type = '', String mime = ''}) =>
      FilePreviewKind.of(
        WorkspaceFile(id: 'f', name: name, fileType: type, mimeType: mime),
      );

  test('tells which files can be previewed', () {
    expect(kind('a.png', type: 'png'), FilePreviewKind.image);
    expect(kind('a', mime: 'image/heic'), FilePreviewKind.image);
    expect(kind('a.svg', type: 'svg'), FilePreviewKind.svg);
    expect(kind('a', mime: 'image/svg+xml'), FilePreviewKind.svg);
    expect(kind('a.csv', type: 'csv'), FilePreviewKind.text);
    expect(kind('a', mime: 'text/plain'), FilePreviewKind.text);
    expect(kind('a', mime: 'application/json'), FilePreviewKind.text);
    expect(kind('a.pdf', type: 'pdf'), FilePreviewKind.none);
    expect(kind('a.docx', type: 'docx'), FilePreviewKind.none);
    expect(kind('a.mp4', type: 'mp4'), FilePreviewKind.none);
  });
}
