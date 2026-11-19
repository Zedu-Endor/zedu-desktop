import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class FakeAuthNotifier extends AuthNotifier {
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
      currentOrganisationSlug: 'test-org',
      avatarUrl: '',
      defaultAvatarUrl: '',
    ),
  );
}

Future<ProviderContainer> pumpIndicator(
  WidgetTester tester,
  String channelId, {
  String? excludeUserId,
}) async {
  final container = ProviderContainer(
    overrides: [authNotifierProvider.overrideWith(FakeAuthNotifier.new)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: buildTestMaterialApp(
        Scaffold(
          body: TypingIndicator(
            channelId: channelId,
            excludeUserId: excludeUserId,
          ),
        ),
      ),
    ),
  );
  return container;
}

void main() {
  group('typingLabel', () {
    TypingUser user(String id, String name) =>
        TypingUser(userId: id, displayName: name);

    test('is empty when nobody is typing', () {
      expect(typingLabel(const []), isEmpty);
    });

    test('names one or two typists', () {
      expect(typingLabel([user('u-2', 'Ada')]), 'Ada is typing...');
      expect(
        typingLabel([user('u-2', 'Ada'), user('u-3', 'Bob')]),
        'Ada and Bob are typing...',
      );
    });

    test('counts three or more typists as others', () {
      expect(
        typingLabel([user('u-1', 'A'), user('u-2', 'B'), user('u-3', 'C')]),
        'A, B and 1 other are typing...',
      );
      expect(
        typingLabel([
          user('u-1', 'A'),
          user('u-2', 'B'),
          user('u-3', 'C'),
          user('u-4', 'D'),
        ]),
        'A, B and 2 others are typing...',
      );
    });
  });

  group('TypingPresenceNotifier', () {
    test('setTyping stores the entry and clearTyping drops it', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(typingPresenceProvider('c-1').notifier);

      notifier.setTyping(userId: 'u-2', displayName: 'Ada');
      expect(
        container.read(typingPresenceProvider('c-1'))['u-2']?.displayName,
        'Ada',
      );

      // Leaving the addTearDown disposal with a pending expiry timer would
      // fire into a disposed container, so clear before the test ends.
      notifier.clearTyping('u-2');
      expect(container.read(typingPresenceProvider('c-1')), isEmpty);
    });

    test('ignores entries without a user or a name', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(typingPresenceProvider('c-1').notifier);

      notifier.setTyping(userId: '', displayName: 'Ada');
      notifier.setTyping(userId: 'u-2', displayName: '');
      expect(container.read(typingPresenceProvider('c-1')), isEmpty);
    });
  });

  group('TypingIndicator', () {
    testWidgets('shows nothing when nobody is typing', (tester) async {
      await pumpIndicator(tester, 'c-1');

      expect(find.textContaining('typing'), findsNothing);
    });

    testWidgets('shows who is typing', (tester) async {
      final container = await pumpIndicator(tester, 'c-1');
      final notifier = container.read(typingPresenceProvider('c-1').notifier);
      notifier.setTyping(userId: 'u-2', displayName: 'Ada');
      await tester.pump();

      expect(find.text('Ada is typing...'), findsOneWidget);

      notifier.clearTyping('u-2');
      await tester.pump();
    });

    testWidgets('hides the excluded user', (tester) async {
      final container = await pumpIndicator(
        tester,
        'c-1',
        excludeUserId: 'user-1',
      );
      final notifier = container.read(typingPresenceProvider('c-1').notifier);
      notifier.setTyping(userId: 'user-1', displayName: 'Test User');
      await tester.pump();

      expect(find.textContaining('typing'), findsNothing);

      notifier.clearTyping('user-1');
      await tester.pump();
    });

    testWidgets('shows two typists together', (tester) async {
      final container = await pumpIndicator(tester, 'c-1');
      final notifier = container.read(typingPresenceProvider('c-1').notifier);
      notifier.setTyping(userId: 'u-2', displayName: 'Ada');
      notifier.setTyping(userId: 'u-3', displayName: 'Bob');
      await tester.pump();

      expect(find.text('Ada and Bob are typing...'), findsOneWidget);

      notifier
        ..clearTyping('u-2')
        ..clearTyping('u-3');
      await tester.pump();
    });

    testWidgets('clears the entry when the keystroke expires', (tester) async {
      final container = await pumpIndicator(tester, 'c-1');
      container
          .read(typingPresenceProvider('c-1').notifier)
          .setTyping(userId: 'u-2', displayName: 'Ada');
      await tester.pump();
      expect(find.text('Ada is typing...'), findsOneWidget);

      // The web client expires typing after 4 seconds; moving past that
      // must take the indicator away without any further events.
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      expect(find.textContaining('typing'), findsNothing);
    });

    testWidgets('is scoped to its own conversation', (tester) async {
      final container = await pumpIndicator(tester, 'c-1');
      final other = container.read(typingPresenceProvider('c-2').notifier);
      other.setTyping(userId: 'u-2', displayName: 'Ada');
      await tester.pump();

      expect(find.textContaining('typing'), findsNothing);

      other.clearTyping('u-2');
      await tester.pump();
    });
  });
}
