import 'package:zedu/core/theme/app_theme.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

/// Searches for "hello" in a panel whose search returns [results].
Future<void> _searchFor(WidgetTester tester, List<String> results) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Row(
          children: [SearchPanel(onClose: () {}, search: (_) async => results)],
        ),
      ),
    ),
  );
  await tester.enterText(find.byType(TextField), 'hello');
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

void main() {
  group('searchResultText', () {
    test('drops paragraph tags', () {
      expect(searchResultText('<p>Hello</p>'), 'Hello');
    });

    test('decodes entities such as &nbsp;', () {
      expect(searchResultText('<p>Hello&nbsp;</p>'), 'Hello');
      expect(searchResultText('Fish &amp; chips'), 'Fish & chips');
    });

    test('keeps paragraphs and line breaks apart', () {
      expect(searchResultText('<p>one</p><p>two</p>'), 'one\n\ntwo');
      expect(searchResultText('<p>first<br>second</p>'), 'first\n\nsecond');
    });

    test('keeps formatting as the chat shows it', () {
      expect(
        searchResultText('<p>Hello <strong>you</strong></p>'),
        'Hello **you**',
      );
    });

    test('drops script and style blocks instead of showing them', () {
      expect(searchResultText('<p>Hi</p><script>alert(1)</script>'), 'Hi');
      expect(
        searchResultText('<STYLE>p { color: red; }</STYLE><p>Hi</p>'),
        'Hi',
      );
    });

    test('returns plain text unchanged', () {
      expect(searchResultText('Plain result'), 'Plain result');
      expect(searchResultText('line one\nline two'), 'line one\nline two');
    });
  });

  group('SearchPanel results', () {
    testWidgets('show HTML messages as readable text without tags', (
      tester,
    ) async {
      await _searchFor(tester, ['<p>Hello</p>', '<p>Hello&nbsp;</p>']);

      expect(find.text('Hello'), findsNWidgets(2));
      expect(find.textContaining('<p>'), findsNothing);
      expect(find.textContaining('&nbsp;'), findsNothing);
    });

    testWidgets('keep separate paragraphs apart', (tester) async {
      await _searchFor(tester, ['<p>one</p><p>two</p>']);

      expect(find.text('one'), findsOneWidget);
      expect(find.text('two'), findsOneWidget);
    });

    testWidgets('never show script content', (tester) async {
      await _searchFor(tester, ['<p>Hi</p><script>alert(1)</script>']);

      expect(find.text('Hi'), findsOneWidget);
      expect(find.textContaining('alert'), findsNothing);
    });

    testWidgets('show plain-text results unchanged', (tester) async {
      await _searchFor(tester, ['Plain result about hello']);

      expect(find.text('Plain result about hello'), findsOneWidget);
    });
  });
}
