import 'dart:async';

import '../../../../../helpers/helpers.dart';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockDmRepository extends Mock implements DmRepository {}

class _SignedOutAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

/// #2939: loadAll must not keep waiting on a notifier that was disposed
/// while a page was loading.
void main() {
  late MockDmRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = MockDmRepository();
    container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(_SignedOutAuth.new),
        dmRepositoryProvider.overrideWithValue(repository),
      ],
    );
  });

  ChatHistoryNotifier open() =>
      container.listen(chatHistoryProvider('ch-1'), (_, _) {}).read();

  testWidgets('returns once the notifier is disposed mid-load', (tester) async {
    // The first page never arrives before the conversation is closed.
    final firstPage = Completer<List<Map<String, dynamic>>>();
    when(
      () => repository.getMessages(any(), page: any(named: 'page')),
    ).thenAnswer((_) => firstPage.future);

    final notifier = open();
    expect(notifier.isLoading, isTrue);

    var finished = false;
    unawaited(notifier.loadAll().whenComplete(() => finished = true));
    await tester.pump(const Duration(milliseconds: 120));
    expect(finished, isFalse, reason: 'still waiting for the first page');

    container.dispose();
    firstPage.complete([
      {'id': 'm1', 'content': 'late', 'user_id': 'u1'},
    ]);
    await tester.pump(const Duration(milliseconds: 120));

    expect(finished, isTrue);
    // The page that arrived after dispose left the flag set; loadAll still
    // returned instead of polling it forever.
    expect(notifier.isLoading, isTrue);
  });

  testWidgets('still loads every page while the notifier is alive', (
    tester,
  ) async {
    final pages = <int, List<Map<String, dynamic>>>{
      1: List.generate(
        20,
        (i) => {'id': 'p1-$i', 'content': 'a', 'user_id': 'u1'},
      ),
      2: [
        {'id': 'p2-0', 'content': 'b', 'user_id': 'u1'},
      ],
    };
    when(
      () => repository.getMessages(any(), page: any(named: 'page')),
    ).thenAnswer((call) async => pages[call.namedArguments[#page]] ?? []);

    final notifier = open();
    var finished = false;
    unawaited(notifier.loadAll().whenComplete(() => finished = true));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    expect(finished, isTrue);
    expect(notifier.hasMore, isFalse);
    expect(notifier.messages.map((m) => m['id']), contains('p2-0'));
    container.dispose();
  });
}
