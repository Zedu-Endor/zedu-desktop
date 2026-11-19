import 'dart:convert';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class _PreviewRepository implements FilesRepository {
  _PreviewRepository(this.bytes);

  final Uint8List bytes;

  @override
  Future<Result<Uint8List>> fetchFilePreview(
    WorkspaceFile file,
    FilePreviewKind kind,
  ) async => Success(bytes);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Uint8List _utf16(String text, Endian endian) {
  final data = ByteData(2 + text.codeUnits.length * 2);
  data.setUint16(0, 0xfeff, endian);
  for (var i = 0; i < text.codeUnits.length; i++) {
    data.setUint16(2 + i * 2, text.codeUnits[i], endian);
  }
  return data.buffer.asUint8List();
}

Future<void> _show(WidgetTester tester, Uint8List bytes) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        filesRepositoryProvider.overrideWithValue(_PreviewRepository(bytes)),
      ],
      child: buildTestMaterialApp(
        FilePreviewDialog(
          file: const WorkspaceFile(
            id: 'encoding-fixture',
            name: 'notes.txt',
            fileType: 'txt',
          ),
          onDownload: () {},
          onOpenExternally: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  const content = 'Zedu preview test: café 👋\nSecond line.';

  for (final endian in [Endian.little, Endian.big]) {
    final label = endian == Endian.little ? 'LE' : 'BE';
    testWidgets('previews BOM-marked UTF-16$label text', (tester) async {
      await _show(tester, _utf16(content, endian));

      expect(find.text(content), findsOneWidget);
      expect(find.text('No preview available'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('preserves UTF-8 text previews', (tester) async {
    await _show(tester, Uint8List.fromList(utf8.encode(content)));

    expect(find.text(content), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('still rejects a binary file with a text extension', (
    tester,
  ) async {
    await _show(tester, Uint8List.fromList([0x61, 0, 0x62]));

    expect(find.text('No preview available'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rejects a truncated UTF-16 code unit without crashing', (
    tester,
  ) async {
    await _show(tester, Uint8List.fromList([0xff, 0xfe, 0x61]));

    expect(find.text('No preview available'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('still rejects NUL characters after UTF-16 decoding', (
    tester,
  ) async {
    await _show(tester, _utf16('binary\u0000data', Endian.little));

    expect(find.text('No preview available'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
