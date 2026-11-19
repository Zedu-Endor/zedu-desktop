import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

Widget _viewer({
  ImageSavePathPicker? onPickSavePath,
  ImageDownloadCallback? onDownload,
}) {
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                fullscreenDialog: true,
                builder: (_) => ImageAttachmentViewer(
                  imageUrl: 'https://example.com/photo.png',
                  fileName: 'photo.png',
                  onPickSavePath: onPickSavePath,
                  onDownload: onDownload,
                ),
              ),
            ),
            child: const Text('Open image'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openViewer(
  WidgetTester tester, {
  ImageSavePathPicker? onPickSavePath,
  ImageDownloadCallback? onDownload,
}) async {
  await tester.pumpWidget(
    _viewer(onPickSavePath: onPickSavePath, onDownload: onDownload),
  );
  await tester.tap(find.text('Open image'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the image full screen and closes', (tester) async {
    await _openViewer(tester);

    expect(find.text('photo.png'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byTooltip('Zoom in'), findsOneWidget);
    expect(find.byTooltip('Rotate image'), findsOneWidget);
    expect(find.byTooltip('Save image'), findsOneWidget);

    await tester.tap(find.byTooltip('Close image viewer'));
    await tester.pumpAndSettle();

    expect(find.text('photo.png'), findsNothing);
    expect(find.text('Open image'), findsOneWidget);
  });

  testWidgets('zoom in and out change the viewer scale', (tester) async {
    await _openViewer(tester);
    final controller = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;

    expect(controller.value.getMaxScaleOnAxis(), 1);

    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pump();
    expect(controller.value.getMaxScaleOnAxis(), closeTo(1.5, 0.001));

    await tester.tap(find.byTooltip('Zoom out'));
    await tester.pump();
    expect(controller.value.getMaxScaleOnAxis(), closeTo(1, 0.001));
  });

  testWidgets('zoom buttons keep the middle of the viewer in place', (
    tester,
  ) async {
    await _openViewer(tester);
    final viewer = find.byType(InteractiveViewer);
    final controller = tester
        .widget<InteractiveViewer>(viewer)
        .transformationController!;
    final center = tester.getSize(viewer).center(Offset.zero);

    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pump();
    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pump();

    expect(controller.value.getMaxScaleOnAxis(), closeTo(2.25, 0.001));
    final sceneCenter = controller.toScene(center);
    expect(sceneCenter.dx, closeTo(center.dx, 0.001));
    expect(sceneCenter.dy, closeTo(center.dy, 0.001));
  });

  testWidgets('zoom buttons follow zoom made outside the toolbar', (
    tester,
  ) async {
    await _openViewer(tester);
    final controller = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;

    // What the mouse wheel leaves behind at the 4x limit.
    controller.value = Matrix4.diagonal3Values(4, 4, 1);
    await tester.pump();

    final zoomIn = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.zoom_in_rounded),
    );
    expect(zoomIn.onPressed, isNull);

    await tester.tap(find.byTooltip('Zoom out'));
    await tester.pump();
    expect(controller.value.getMaxScaleOnAxis(), closeTo(4 / 1.5, 0.001));
  });

  testWidgets('rotate turns the image a quarter at a time', (tester) async {
    await _openViewer(tester);

    expect(tester.widget<RotatedBox>(find.byType(RotatedBox)).quarterTurns, 0);

    await tester.tap(find.byTooltip('Rotate image'));
    await tester.pump();

    expect(tester.widget<RotatedBox>(find.byType(RotatedBox)).quarterTurns, 1);
  });

  testWidgets('save asks for the path before downloading and confirms', (
    tester,
  ) async {
    final calls = <String>[];
    await _openViewer(
      tester,
      onPickSavePath: (fileName) async {
        calls.add('pick $fileName');
        return '/tmp/chosen.png';
      },
      onDownload: (url, path) async {
        calls.add('download $url $path');
        return true;
      },
    );

    await tester.tap(find.byTooltip('Save image'));
    await tester.pump();
    await tester.pump();

    expect(calls, [
      'pick photo.png',
      'download https://example.com/photo.png /tmp/chosen.png',
    ]);
    expect(find.text('Saved photo.png'), findsOneWidget);
  });

  testWidgets('cancelling the save dialog shows no message', (tester) async {
    var downloaded = false;
    await _openViewer(
      tester,
      onPickSavePath: (_) async => null,
      onDownload: (_, _) async {
        downloaded = true;
        return true;
      },
    );

    await tester.tap(find.byTooltip('Save image'));
    await tester.pump();
    await tester.pump();

    expect(downloaded, isFalse);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.textContaining('Could not save'), findsNothing);
    expect(find.byIcon(Icons.download_rounded), findsOneWidget);
  });

  testWidgets('save reports a failure without closing the viewer', (
    tester,
  ) async {
    await _openViewer(
      tester,
      onPickSavePath: (_) async => '/tmp/chosen.png',
      onDownload: (_, _) async => false,
    );

    await tester.tap(find.byTooltip('Save image'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Could not save photo.png'), findsOneWidget);
    expect(find.text('photo.png'), findsOneWidget);
  });
}
