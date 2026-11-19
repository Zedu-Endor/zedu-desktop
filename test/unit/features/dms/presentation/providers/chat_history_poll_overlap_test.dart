import 'dart:async';

import '../../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class _MockDmRepository extends Mock implements DmRepository {}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState(
    status: AuthStatus.authenticated,
    user: User(
      id: 'user-1',
      firstName: 'Test',
      lastName: 'User',
      email: 'test@example.com',
      phone: '',
      username: 'testuser',
      isVerified: true,
      isOnboarded: true,
      createdAt: DateTime(2026),
      currentOrg: 'org-1',
      currentOrganisationSlug: 'org-slug',
      avatarUrl: '',
      defaultAvatarUrl: '',
    ),
  );
}

void main() {
  testWidgets('a slow poll is not overlapped by the next tick (#2656)', (
    tester,
  ) async {
    final repo = _MockDmRepository();
    final slowPoll = Completer<List<Map<String, dynamic>>>();
    var calls = 0;
    when(() => repo.getMessages(any(), page: any(named: 'page'))).thenAnswer((
      _,
    ) {
      calls++;
      // The first call is the initial load; the first poll never answers
      // until the test lets it.
      if (calls == 1) return Future.value(<Map<String, dynamic>>[]);
      if (calls == 2) return slowPoll.future;
      return Future.value(<Map<String, dynamic>>[]);
    });

    final container = ProviderContainer(
      overrides: [
        dmRepositoryProvider.overrideWithValue(repo),
        authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
      ],
    );
    final sub = container.listen(chatHistoryProvider('ch-1'), (_, _) {});
    await tester.pump();
    expect(calls, 1);

    // First tick: the poll starts and hangs.
    await tester.pump(const Duration(seconds: 10));
    expect(calls, 2);

    // Two more ticks while it is still running: no new requests.
    await tester.pump(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 10));
    expect(calls, 2);

    // Once it answers, the next tick polls again.
    slowPoll.complete(<Map<String, dynamic>>[]);
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    expect(calls, 3);

    sub.close();
    container.dispose();
  });
}
