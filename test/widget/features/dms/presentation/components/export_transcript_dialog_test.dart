import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockDmRepository extends Mock implements DmRepository {}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState();
}

Map<String, dynamic> _message(
  String id,
  String content, {
  String userId = 'u1',
  String createdAt = '2026-11-05T09:05:00Z',
  List<Map<String, dynamic>>? media,
}) => {
  'id': id,
  'content': content,
  'user_id': userId,
  'created_at': createdAt,
  'media': ?media,
};

void main() {
  late MockDmRepository repository;
  late ProviderContainer container;
  late ChatHistoryNotifier history;
  late List<({String fileName, String contents})> saved;

  setUp(() {
    if (locator.isRegistered<AppConfig>()) locator.unregister<AppConfig>();
    locator.registerSingleton<AppConfig>(
      const AppConfig(apiBaseUrl: 'http://test', usesMockData: false),
    );
    repository = MockDmRepository();
    when(
      () => repository.getMessages(any(), page: any(named: 'page')),
    ).thenAnswer(
      (_) async => [
        _message('m1', '<p>See you at <strong>noon</strong></p>'),
        _message(
          'm2',
          'On my way',
          userId: 'me',
          createdAt: '2026-11-05T09:06:00Z',
        ),
        _message(
          'm3',
          '',
          createdAt: '2026-11-05T09:07:00Z',
          media: [
            {
              'file_name': 'agenda.pdf',
              'file_type': 'pdf',
              'file_link': 'https://files.test/agenda.pdf',
            },
          ],
        ),
      ],
    );
    container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
        dmRepositoryProvider.overrideWithValue(repository),
      ],
    );
    // The chat area keeps this provider alive while the dialog is open.
    container.listen(chatHistoryProvider('ch-1'), (_, _) {});
    history = container.read(chatHistoryProvider('ch-1'));
    saved = [];
  });

  tearDown(() {
    container.dispose();
    if (locator.isRegistered<AppConfig>()) locator.unregister<AppConfig>();
  });

  Future<void> pumpDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExportTranscriptDialog(
            conversationName: 'Ada Lovelace',
            history: history,
            now: () => DateTime(2026, 11, 5, 12, 30),
            save: ({required fileName, required contents}) async {
              saved.add((fileName: fileName, contents: contents));
              return '/tmp/$fileName';
            },
          ),
        ),
      ),
    );
    // Let the first page load and loadAll finish.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
  }

  testWidgets('exports the conversation as plain text by default', (
    tester,
  ) async {
    await pumpDialog(tester);

    expect(find.text('3 messages will be exported.'), findsOneWidget);

    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    expect(saved, hasLength(1));
    final file = saved.single;
    expect(file.fileName, 'ada-lovelace-transcript-2026-11-05.txt');
    expect(file.contents, startsWith('Conversation with Ada Lovelace'));
    expect(file.contents, contains('Ada Lovelace'));
    expect(file.contents, contains('You'));
    expect(file.contents, contains('See you at noon'));
    expect(file.contents, contains('[Attachment] agenda.pdf'));
    expect(find.byType(ExportTranscriptDialog), findsNothing);
  });

  testWidgets('exports Markdown when that format is chosen', (tester) async {
    await pumpDialog(tester);

    await tester.tap(find.text('Markdown (.md)'));
    await tester.pump();
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    expect(saved, hasLength(1));
    final file = saved.single;
    expect(file.fileName, 'ada-lovelace-transcript-2026-11-05.md');
    expect(file.contents, contains('# Conversation with Ada Lovelace'));
    expect(file.contents, contains('**noon**'));
    expect(
      file.contents,
      contains('- [agenda.pdf](https://files.test/agenda.pdf)'),
    );
  });

  testWidgets('cancelling writes nothing', (tester) async {
    await pumpDialog(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(saved, isEmpty);
    expect(find.byType(ExportTranscriptDialog), findsNothing);
  });
}
