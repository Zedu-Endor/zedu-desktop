import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class FakeSecureStorageService extends Fake implements SecureStorageService {
  final _values = <String, String>{};

  @override
  Future<String?> readData(String key) async => _values[key];

  @override
  Future<void> writeData(String key, String value) async =>
      _values[key] = value;

  @override
  Future<void> deleteValue(String key) async => _values.remove(key);
}

Future<TextField> pumpComposer(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dmDraftStoreProvider.overrideWith(
          (ref) => DmDraftStore(
            FakeSecureStorageService(),
            userId: 'user-1',
            orgId: 'org-1',
          ),
        ),
      ],
      child: buildTestMaterialApp(
        const Scaffold(
          body: DmMessageComposer(recipientName: 'Ada', channelId: 'dm-1'),
        ),
      ),
    ),
  );
  return tester.widget<TextField>(find.byType(TextField));
}

Future<void> typeAndPlaceCursorAtEnd(
  WidgetTester tester,
  TextField field,
  String text,
) async {
  await tester.enterText(find.byType(TextField), text);
  field.controller!.selection = TextSelection.collapsed(offset: text.length);
  await tester.pump();
}

/// Runs [body] against the composer, then empties it so the composer's
/// draft flush in `dispose` has nothing to save when the test unmounts it.
void composerTest(
  String description,
  Future<void> Function(WidgetTester tester, TextField field) body,
) {
  testWidgets(description, (tester) async {
    final field = await pumpComposer(tester);
    await body(tester, field);
    field.controller!.clear();
    await tester.pump(const Duration(milliseconds: 300));
  });
}

Future<void> tapDivider(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Divider'));
  // Let the composer's debounced draft save run.
  await tester.pump(const Duration(milliseconds: 300));
}

Widget buildComposerUnderTest() {
  return ProviderScope(
    overrides: [
      dmDraftStoreProvider.overrideWith(
        (ref) => DmDraftStore(
          FakeSecureStorageService(),
          userId: 'user-1',
          orgId: 'org-1',
        ),
      ),
    ],
    child: buildTestMaterialApp(
      const Scaffold(
        body: DmMessageComposer(
          recipientName: 'Ada',
          channelId: 'channel-1',
          participants: [],
        ),
      ),
    ),
  );
}

TextEditingController composerController(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).controller;

Future<void> typeAndSelect(
  WidgetTester tester,
  String text, {
  TextSelection? selection,
}) async {
  await tester.tap(find.byType(TextField));
  await tester.enterText(find.byType(TextField), text);
  composerController(tester).selection =
      selection ?? TextSelection(baseOffset: 0, extentOffset: text.length);
  await tester.pump();
}

Future<void> pressShortcut(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  LogicalKeyboardKey modifier = LogicalKeyboardKey.controlLeft,
}) async {
  await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(modifier);
  await tester.pump();
}

void main() {
  group('DmMessageComposer Divider button', () {
    composerTest('inserts a divider into an empty composer', (
      tester,
      field,
    ) async {
      await tapDivider(tester);

      expect(field.controller!.text, '---\n');
      expect(
        field.controller!.selection,
        const TextSelection.collapsed(offset: 4),
      );
    });

    composerTest(
      'puts a blank line before the divider so it is not read as a heading',
      (tester, field) async {
        await typeAndPlaceCursorAtEnd(tester, field, 'hello');

        await tapDivider(tester);

        expect(field.controller!.text, 'hello\n\n---\n');
        expect(
          field.controller!.selection,
          const TextSelection.collapsed(offset: 'hello\n\n---\n'.length),
        );
      },
    );

    composerTest('adds only one newline when the text already ends with one', (
      tester,
      field,
    ) async {
      await typeAndPlaceCursorAtEnd(tester, field, 'hello\n');

      await tapDivider(tester);

      expect(field.controller!.text, 'hello\n\n---\n');
    });

    composerTest('inserts after the selection without removing it', (
      tester,
      field,
    ) async {
      await tester.enterText(find.byType(TextField), 'hello world');
      field.controller!.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 5,
      );
      await tester.pump();

      await tapDivider(tester);

      expect(field.controller!.text, 'hello\n\n---\n world');
      expect(
        field.controller!.selection,
        const TextSelection.collapsed(offset: 'hello\n\n---\n'.length),
      );
    });
  });

  group('DmMessageComposer formatting shortcuts', () {
    testWidgets('Ctrl+B wraps the selected text in bold markers', (
      tester,
    ) async {
      await tester.pumpWidget(buildComposerUnderTest());
      await typeAndSelect(tester, 'hello');

      await pressShortcut(tester, LogicalKeyboardKey.keyB);

      expect(composerController(tester).text, '**hello**');
    });

    testWidgets('Ctrl+I wraps the selected text in italic markers', (
      tester,
    ) async {
      await tester.pumpWidget(buildComposerUnderTest());
      await typeAndSelect(tester, 'hello');

      await pressShortcut(tester, LogicalKeyboardKey.keyI);

      expect(composerController(tester).text, '*hello*');
    });

    testWidgets('Cmd+B works the same as Ctrl+B', (tester) async {
      await tester.pumpWidget(buildComposerUnderTest());
      await typeAndSelect(tester, 'hello');

      await pressShortcut(
        tester,
        LogicalKeyboardKey.keyB,
        modifier: LogicalKeyboardKey.metaLeft,
      );

      expect(composerController(tester).text, '**hello**');
    });

    testWidgets('with no selection, inserts markers with cursor between', (
      tester,
    ) async {
      await tester.pumpWidget(buildComposerUnderTest());
      await typeAndSelect(
        tester,
        'hi ',
        selection: const TextSelection.collapsed(offset: 3),
      );

      await pressShortcut(tester, LogicalKeyboardKey.keyB);

      final controller = composerController(tester);
      expect(controller.text, 'hi ****');
      expect(controller.selection, const TextSelection.collapsed(offset: 5));
    });
  });
}
