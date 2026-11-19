import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class _MockChannelRepository extends Mock implements ChannelRepository {}

class _EmptyHistory extends ChangeNotifier implements ChatHistoryNotifier {
  _EmptyHistory(this.channelId);

  @override
  final String channelId;

  @override
  List<Map<String, dynamic>> messages = [];

  @override
  String get currentUserName => 'Test User';

  @override
  String? get currentUserAvatarUrl => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Every text-bearing span of the single message body, markers included or not.
List<TextSpan> _spansOf(WidgetTester tester) {
  final root = tester
      .widget<SelectableText>(find.byType(SelectableText))
      .textSpan!;
  final spans = <TextSpan>[];
  root.visitChildren((InlineSpan child) {
    if (child is TextSpan) spans.add(child);
    return true;
  });
  return spans;
}

List<String> _words(List<TextSpan> spans) {
  return spans.map((span) => span.text ?? '').toList();
}

TextSpan? _styled(
  List<TextSpan> spans,
  String word,
  bool Function(TextStyle?) check,
) {
  final matches = spans.where((span) => span.text == word && check(span.style));
  return matches.isEmpty ? null : matches.first;
}

Future<void> _pumpMessage(WidgetTester tester, String text) async {
  final repository = _MockChannelRepository();
  final result = Success(
    ChannelMessagePage(
      messages: [ChannelMessage(senderName: 'Ada', text: text)],
      hasMore: false,
    ),
  );
  when(
    () => repository.fetchChannelMessages('ch-1'),
  ).thenAnswer((_) async => result);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        channelRepositoryProvider.overrideWithValue(repository),
        chatHistoryProvider.overrideWith((_, _) => _EmptyHistory('ch-1')),
      ],
      retry: (_, _) => null,
      child: buildTestMaterialApp(
        const Scaffold(
          body: ChannelMessageList(
            channelId: 'ch-1',
            empty: Text('Welcome to #general'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('ChannelMessageList inline Markdown', () {
    testWidgets('renders bold and drops the markers', (tester) async {
      await _pumpMessage(tester, '**ship it**');

      final spans = _spansOf(tester);
      expect(_words(spans), contains('ship it'));
      expect(_words(spans).join(), isNot(contains('**')));
      expect(
        _styled(spans, 'ship it', (s) => s?.fontWeight == FontWeight.bold),
        isNotNull,
      );
    });

    testWidgets('renders italic and drops the markers', (tester) async {
      await _pumpMessage(tester, '*type slowly*');

      final spans = _spansOf(tester);
      expect(_words(spans), contains('type slowly'));
      expect(_words(spans).join(), isNot(contains('*')));
      expect(
        _styled(spans, 'type slowly', (s) => s?.fontStyle == FontStyle.italic),
        isNotNull,
      );
    });

    testWidgets('renders inline code and drops the markers', (tester) async {
      await _pumpMessage(tester, 'run `npm test` now');

      final spans = _spansOf(tester);
      expect(_words(spans), contains('run '));
      expect(_words(spans).join(), isNot(contains('`')));
      expect(
        _styled(spans, 'npm test', (s) => s?.fontFamily == 'monospace'),
        isNotNull,
      );
    });

    testWidgets('leaves an ordinary message unstyled', (tester) async {
      await _pumpMessage(tester, 'hello there');

      final spans = _spansOf(tester);
      expect(_words(spans), contains('hello there'));
      expect(
        _styled(spans, 'hello there', (s) => s?.fontWeight == FontWeight.bold),
        isNull,
      );
    });

    testWidgets('opens a URL in a plain message', (tester) async {
      final opened = <Uri>[];
      final original = messageLinkLauncher;
      messageLinkLauncher = (uri) async {
        opened.add(uri);
        return true;
      };
      addTearDown(() => messageLinkLauncher = original);

      await _pumpMessage(tester, 'https://example.com/general');
      await tester.tapAt(
        tester.getTopLeft(find.byType(SelectableText)) + const Offset(20, 8),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(opened, [Uri.parse('https://example.com/general')]);
    });
  });
}
