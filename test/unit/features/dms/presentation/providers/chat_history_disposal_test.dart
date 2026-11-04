import 'dart:async';

import '../../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class _Repository extends Mock implements DmRepository {}

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

class _Storage extends Fake implements SecureStorageService {
  final read = Completer<String?>();

  @override
  Future<String?> readData(String key) => read.future;
}

void main() {
  late _Repository repository;

  ProviderContainer createContainer({_Storage? storage}) => ProviderContainer(
    overrides: [
      dmRepositoryProvider.overrideWithValue(repository),
      authNotifierProvider.overrideWith(_Auth.new),
      if (storage != null)
        dmHistoryClearStoreProvider.overrideWithValue(
          DmHistoryClearStore(storage, userId: 'user'),
        ),
    ],
  );

  ChatHistoryNotifier open(ProviderContainer container) =>
      container.listen(chatHistoryProvider('ch-1'), (_, _) {}).read();

  setUp(() {
    repository = _Repository();
    when(
      () => repository.getMessages(any(), page: any(named: 'page')),
    ).thenAnswer((_) async => []);
  });

  testWidgets(
    'disposal during clear-store read never starts history or polling',
    (tester) async {
      final storage = _Storage();
      final container = createContainer(storage: storage);
      open(container);
      container.dispose();

      storage.read.complete(null);
      await tester.pump();
      await tester.pump(const Duration(seconds: 20));

      verifyNever(
        () => repository.getMessages(any(), page: any(named: 'page')),
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final fails in [false, true]) {
    testWidgets('initial history completing after disposal (failure: $fails)', (
      tester,
    ) async {
      final response = Completer<List<Map<String, dynamic>>>();
      when(
        () => repository.getMessages(any(), page: any(named: 'page')),
      ).thenAnswer((_) => response.future);
      final container = createContainer();
      final notifier = open(container);
      await tester.pump();
      container.dispose();

      if (fails) {
        response.completeError(StateError('offline'));
      } else {
        response.complete([
          {'id': 'late'},
        ]);
      }
      await tester.pump();
      await tester.pump(const Duration(seconds: 20));

      expect(notifier.messages, isEmpty);
      verify(() => repository.getMessages('ch-1', page: 1)).called(1);
      expect(tester.takeException(), isNull);
    });

    for (final retry in [false, true]) {
      testWidgets(
        'pending send after disposal (retry: $retry, failure: $fails)',
        (tester) async {
          final response = Completer<String>();
          when(
            () => repository.sendMessage(
              any(),
              any(),
              media: any(named: 'media'),
              mentions: any(named: 'mentions'),
              isChannel: any(named: 'isChannel'),
            ),
          ).thenAnswer((_) => response.future);
          final container = createContainer();
          final notifier = open(container);
          await tester.pump();
          if (retry) {
            notifier.messages = [
              {'id': 'failed', 'content': 'hello', 'status': 'failed'},
            ];
          }
          final sending = retry
              ? notifier.retryMessage('failed')
              : notifier.sendMessage('hello');
          final before = notifier.messages;
          container.dispose();

          if (fails) {
            response.completeError(StateError('offline'));
          } else {
            response.complete('thread');
          }
          await sending;

          expect(identical(notifier.messages, before), isTrue);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('paging and loadAll stop when disposed during a page request', (
    tester,
  ) async {
    final container = createContainer();
    final notifier = open(container);
    await tester.pump();
    notifier.hasMore = true;
    final response = Completer<List<Map<String, dynamic>>>();
    when(
      () => repository.getMessages('ch-1', page: 2),
    ).thenAnswer((_) => response.future);
    final loading = notifier.loadMore();
    final loadingAll = notifier.loadAll();
    container.dispose();
    response.complete([
      {'id': 'late'},
    ]);
    await loading;
    await tester.pump(const Duration(milliseconds: 50));
    await loadingAll;

    expect(notifier.page, 1);
    expect(notifier.messages, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('queued edit never reads the disposed provider', (tester) async {
    final container = createContainer();
    final notifier = open(container);
    await tester.pump();
    notifier.messages = [
      {'id': 'm1', 'content': 'original'},
    ];
    final editing = notifier.saveEdit('m1', 'edited');
    container.dispose();
    await editing;

    expect(notifier.messages.single['content'], 'original');
    verifyNever(
      () => repository.editMessage(
        any(),
        content: any(named: 'content'),
        threadId: any(named: 'threadId'),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('an in-flight poll cannot replace messages after disposal', (
    tester,
  ) async {
    when(
      () => repository.getMessages(any(), page: any(named: 'page')),
    ).thenAnswer(
      (_) async => [
        {'id': 'm1', 'content': 'original'},
      ],
    );
    final container = createContainer();
    final notifier = open(container);
    await tester.pump();
    final response = Completer<List<Map<String, dynamic>>>();
    when(
      () => repository.getMessages(any(), page: any(named: 'page')),
    ).thenAnswer((_) => response.future);
    await tester.pump(const Duration(seconds: 10));
    container.dispose();

    response.complete([
      {'id': 'm1', 'content': 'updated'},
    ]);
    await tester.pump();

    expect(notifier.messages.single['content'], 'original');
    expect(tester.takeException(), isNull);
  });

  for (final deleting in [false, true]) {
    testWidgets(
      'failed mutation after disposal cannot roll back (delete: $deleting)',
      (tester) async {
        final response = Completer<void>();
        when(
          () => repository.editMessage(
            any(),
            content: any(named: 'content'),
            threadId: any(named: 'threadId'),
          ),
        ).thenAnswer((_) => response.future);
        when(
          () => repository.deleteMessage(
            threadId: any(named: 'threadId'),
            channelId: any(named: 'channelId'),
          ),
        ).thenAnswer((_) => response.future);
        final container = createContainer();
        final notifier = open(container);
        await tester.pump();
        notifier.messages = [
          {'id': 'm1', 'content': 'original'},
        ];
        final mutation = deleting
            ? notifier.deleteMessage('m1')
            : notifier.saveEdit('m1', 'edited');
        await tester.pump();
        final before = notifier.messages;
        container.dispose();
        response.completeError(StateError('offline'));
        await mutation;

        expect(identical(notifier.messages, before), isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
