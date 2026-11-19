import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

const _saved = NotificationPreferences(
  mode: NotificationMode.allMessages,
  quietHoursEnabled: false,
  pauseFrom: 22 * 60,
  resumeAt: 7 * 60,
  emailNotifications: false,
  differentMobileSettings: false,
  timezone: 'Africa/Lagos',
);

/// A profile notifier that starts on Notifications with [_saved] loaded and
/// never calls the API. Saving applies the preferences straight away, or
/// fails when [failSave] is set.
class _FakeUserProfileNotifier extends UserProfileNotifier {
  _FakeUserProfileNotifier({this.failSave = false});

  final bool failSave;
  final saves = <NotificationPreferences>[];

  @override
  UserProfileState build() {
    return const UserProfileState(
      section: UserProfileSection.notifications,
      notifications: _saved,
    );
  }

  @override
  Future<void> updateNotificationPreferences(
    NotificationPreferences preferences,
  ) async {
    saves.add(preferences);
    if (failSave) return;
    state = state.copyWith(notifications: preferences);
  }
}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState();
}

class _FakeWorkspaceNotifier extends WorkspaceNotifier {
  @override
  WorkspaceState build() => const WorkspaceState();
}

final _mentions = find.byKey(const ValueKey('notification-mode-mentionsOnly'));
final _allMessages = find.byKey(
  const ValueKey('notification-mode-allMessages'),
);
final _dialog = find.text('Unsaved changes');

Future<_FakeUserProfileNotifier> _pump(
  WidgetTester tester, {
  bool failSave = false,
}) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final profile = _FakeUserProfileNotifier(failSave: failSave);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userProfileNotifierProvider.overrideWith(() => profile),
        authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
        orgCreditBalanceProvider.overrideWithValue(0),
        workspaceProvider.overrideWith(_FakeWorkspaceNotifier.new),
      ],
      child: buildTestMaterialApp(const UserProfileView()),
    ),
  );
  await tester.pump();
  return profile;
}

UserProfileSection _section(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(UserProfileView)),
).read(userProfileNotifierProvider).section;

void main() {
  group('UserProfileView leaving Notifications', () {
    testWidgets('switches section without a prompt when nothing changed', (
      tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.text('Security'));
      await tester.pumpAndSettle();

      expect(_dialog, findsNothing);
      expect(_section(tester), UserProfileSection.security);
    });

    testWidgets('asks before leaving with unsaved changes', (tester) async {
      await _pump(tester);
      await tester.tap(_mentions);
      await tester.pump();

      await tester.tap(find.text('Security'));
      await tester.pumpAndSettle();

      expect(_dialog, findsOneWidget);
      expect(_section(tester), UserProfileSection.notifications);
    });

    testWidgets('Cancel stays on Notifications with the edits intact', (
      tester,
    ) async {
      await _pump(tester);
      await tester.tap(_mentions);
      await tester.pump();

      await tester.tap(find.text('Security'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(_dialog, findsNothing);
      expect(_section(tester), UserProfileSection.notifications);
      expect(find.text('You have unsaved changes'), findsOneWidget);
    });

    testWidgets('Discard leaves and drops the edits', (tester) async {
      await _pump(tester);
      await tester.tap(_mentions);
      await tester.pump();

      await tester.tap(find.text('Security'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(_section(tester), UserProfileSection.security);
      await tester.tap(find.text('Notifications').first);
      await tester.pumpAndSettle();
      expect(_dialog, findsNothing);
      expect(find.text('You have unsaved changes'), findsNothing);
    });

    testWidgets('Save stores the edits and then leaves', (tester) async {
      final profile = await _pump(tester);
      await tester.tap(_mentions);
      await tester.pump();

      await tester.tap(find.text('Security'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(profile.saves.single.mode, NotificationMode.mentionsOnly);
      expect(_section(tester), UserProfileSection.security);
    });

    testWidgets('a failed Save keeps the user on Notifications', (
      tester,
    ) async {
      final profile = await _pump(tester, failSave: true);
      await tester.tap(_mentions);
      await tester.pump();

      await tester.tap(find.text('Security'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(profile.saves, hasLength(1));
      expect(_section(tester), UserProfileSection.notifications);
      expect(find.text('You have unsaved changes'), findsOneWidget);
    });

    testWidgets('no prompt once the edits are put back', (tester) async {
      await _pump(tester);
      await tester.tap(_mentions);
      await tester.pump();
      await tester.tap(_allMessages);
      await tester.pump();

      await tester.tap(find.text('Security'));
      await tester.pumpAndSettle();

      expect(_dialog, findsNothing);
      expect(_section(tester), UserProfileSection.security);
    });
  });
}
