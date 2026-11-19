import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../helpers/helpers.dart';

/// Records the text of every `Clipboard.setData` call in [copied].
void _mockClipboard(List<String> copied) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      });
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(800, 1200),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    ),
  );
  await tester.pump();
}

void main() {
  group('splitMarkdownChunks', () {
    test('leaves text without fences whole', () {
      final chunks = splitMarkdownChunks('just *text* here');
      expect(chunks, hasLength(1));
      expect(chunks.single.isCode, isFalse);
      expect(chunks.single.text, 'just *text* here');
    });

    test('keeps the exact code and language of a fenced block', () {
      final chunks = splitMarkdownChunks(
        'Run this:\n```dart\nvoid main() {}\n```\nDone.',
      );
      expect(chunks, hasLength(3));
      expect(chunks[0].isCode, isFalse);
      expect(chunks[1].isCode, isTrue);
      expect(chunks[1].code, 'void main() {}\n');
      expect(chunks[1].language, 'dart');
      expect(chunks[2].isCode, isFalse);
    });

    test('leaves an unclosed fence as text', () {
      const source = '```dart\nvoid main() {}';
      final chunks = splitMarkdownChunks(source);
      expect(chunks, hasLength(1));
      expect(chunks.single.isCode, isFalse);
      expect(chunks.single.text, source);
    });
  });

  group('CodeBlock', () {
    testWidgets('shows the code and its language', (tester) async {
      await _pump(
        tester,
        const CodeBlock(code: 'void main() {}', language: 'dart'),
      );

      expect(find.text('void main() {}'), findsOneWidget);
      expect(find.text('dart'), findsOneWidget);
      expect(find.byTooltip('Copy code block'), findsOneWidget);
    });

    testWidgets('copies the code itself, not an empty string', (tester) async {
      final copied = <String>[];
      _mockClipboard(copied);
      await _pump(tester, const CodeBlock(code: 'flutter run', language: 'sh'));

      await tester.tap(find.byTooltip('Copy code block'));
      await tester.pump();

      expect(copied, ['flutter run']);
    });

    testWidgets('confirms the copy with a check', (tester) async {
      _mockClipboard([]);
      await _pump(tester, const CodeBlock(code: 'hi'));

      expect(find.byIcon(Icons.copy_outlined), findsOneWidget);
      await tester.tap(find.byTooltip('Copy code block'));
      await tester.pump();

      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('wraps horizontal code scroll view with a Scrollbar', (
      tester,
    ) async {
      await _pump(
        tester,
        const CodeBlock(
          code: 'very long line of code that scrolls horizontally',
          language: 'dart',
        ),
      );

      final scrollbarFinder = find.byType(Scrollbar);
      expect(scrollbarFinder, findsOneWidget);

      final scrollView = find.descendant(
        of: scrollbarFinder,
        matching: find.byType(SingleChildScrollView),
      );
      expect(scrollView, findsOneWidget);
    });
  });

  group('MessageBubble code blocks', () {
    testWidgets('a fenced block copies its code', (tester) async {
      final copied = <String>[];
      _mockClipboard(copied);
      await _pump(
        tester,
        const MessageBubble(
          author: 'Ada',
          text: 'Run this:\n```dart\nvoid main() {}\n```',
          timestamp: '10:00',
        ),
      );

      expect(find.byTooltip('Copy code block'), findsOneWidget);

      await tester.tap(find.byTooltip('Copy code block'));
      await tester.pump();

      expect(copied, hasLength(1));
      expect(copied.single, contains('void main() {}'));
    });

    testWidgets('a message without fences has no copy button', (tester) async {
      _mockClipboard([]);
      await _pump(
        tester,
        const MessageBubble(
          author: 'Ada',
          text: 'Hello *there*',
          timestamp: '10:00',
        ),
      );

      expect(find.byTooltip('Copy code block'), findsNothing);
      expect(find.byType(MarkdownBody), findsOneWidget);
    });
  });
}
