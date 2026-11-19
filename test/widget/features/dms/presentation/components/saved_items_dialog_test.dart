import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class MockSecureStorageService extends Mock implements SecureStorageService {}

SavedMessage saved(
  String messageId, {
  String content = 'hello',
  String conversation = 'Ada Lovelace',
  DateTime? savedAt,
}) => SavedMessage(
  messageId: messageId,
  channelId: 'ch-1',
  conversationName: conversation,
  senderName: 'Ada Lovelace',
  content: content,
  messageCreatedAt: DateTime(2026, 10, 17, 8),
  savedAt: savedAt ?? DateTime.now(),
);

void main() {
  late MockSecureStorageService storage;

  setUp(() {
    storage = MockSecureStorageService();
    when(() => storage.readData(any())).thenAnswer((_) async => null);
    when(() => storage.writeData(any(), any())).thenAnswer((_) async {});
  });

  Future<SavedMessagesStore> pumpDialog(
    WidgetTester tester, {
    List<SavedMessage> items = const [],
  }) async {
    final store = SavedMessagesStore(storage, userId: 'user-1');
    await store.load();
    for (final item in items) {
      await store.save(item);
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [savedMessagesStoreProvider.overrideWith((ref) => store)],
        child: buildTestMaterialApp(const Scaffold(body: SavedItemsDialog())),
      ),
    );
    await tester.pumpAndSettle();
    return store;
  }

  testWidgets('shows an empty state before anything is saved', (tester) async {
    await pumpDialog(tester);

    expect(find.text('Saved items'), findsOneWidget);
    expect(find.textContaining('No saved messages yet'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('lists saved messages with their conversation and sender', (
    tester,
  ) async {
    await pumpDialog(
      tester,
      items: [
        saved('m1', content: 'older save', savedAt: DateTime(2026, 11, 4, 9)),
        saved(
          'm2',
          content: 'newest save',
          conversation: 'Bola',
          savedAt: DateTime(2026, 11, 5, 9),
        ),
      ],
    );

    expect(find.byType(ListTile), findsNWidgets(2));
    expect(find.text('newest save'), findsOneWidget);
    expect(find.text('older save'), findsOneWidget);
    expect(find.text('Bola'), findsOneWidget);

    final titles = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((tile) => ((tile.title as Text).data))
        .toList();
    expect(titles, ['Bola', 'Ada Lovelace']);
  });

  testWidgets('removing an entry takes it out of the list', (tester) async {
    final store = await pumpDialog(tester, items: [saved('m1')]);
    expect(store.items, hasLength(1));

    await tester.tap(find.byTooltip('Remove from Saved items'));
    await tester.pumpAndSettle();

    expect(store.items, isEmpty);
    expect(find.textContaining('No saved messages yet'), findsOneWidget);
  });

  group('savedAtLabel', () {
    final now = DateTime(2026, 11, 5, 15, 30);

    test('labels today and yesterday by name', () {
      expect(
        savedAtLabel(DateTime(2026, 11, 5, 14, 32), now),
        'today at 2:32 PM',
      );
      expect(
        savedAtLabel(DateTime(2026, 11, 4, 9, 5), now),
        'yesterday at 9:05 AM',
      );
    });

    test('labels older saves with their date', () {
      expect(
        savedAtLabel(DateTime(2026, 10, 28, 18, 10), now),
        'Oct 28 at 6:10 PM',
      );
    });

    test('shows midnight and noon as 12', () {
      expect(
        savedAtLabel(DateTime(2026, 11, 5, 0, 7), now),
        'today at 12:07 AM',
      );
      expect(
        savedAtLabel(DateTime(2026, 11, 5, 12, 0), now),
        'today at 12:00 PM',
      );
    });
  });
}
