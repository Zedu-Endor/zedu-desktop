import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class FakeWorkspaceNotifier extends WorkspaceNotifier {
  @override
  WorkspaceState build() => const WorkspaceState(
    workspaces: [Workspace(id: '1', name: 'Acme', avatar: 'A')],
    selectedWorkspace: Workspace(id: '1', name: 'Acme', avatar: 'A'),
  );
}

class FailingSwitchNotifier extends WorkspaceNotifier {
  @override
  WorkspaceState build() => const WorkspaceState(
    workspaces: [
      Workspace(id: '1', name: 'Acme', avatar: 'A'),
      Workspace(id: '2', name: 'Globex', avatar: 'G'),
    ],
    selectedWorkspace: Workspace(id: '1', name: 'Acme', avatar: 'A'),
  );

  @override
  Future<String?> switchWorkspace(Workspace workspace) async =>
      WorkspaceNotifier.switchErrorMessage;
}

// Keeps the invite dialog away from the locator and the API.
class FakeUserProfileNotifier extends UserProfileNotifier {
  @override
  UserProfileState build() => const UserProfileState();

  @override
  Future<List<TeamMember>> fetchOrganisationMembers() async => const [];
}

Widget buildSwitcherUnderTest({WorkspaceNotifier Function()? notifier}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const Align(
                  alignment: Alignment.topLeft,
                  child: WorkspaceSwitcherList(),
                ),
              ),
              child: const Text('Open menu'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: AppRouter.profile,
        builder: (context, state) => const Scaffold(body: Text('Profile page')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      workspaceProvider.overrideWith(notifier ?? FakeWorkspaceNotifier.new),
      userProfileNotifierProvider.overrideWith(FakeUserProfileNotifier.new),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('WorkspaceSwitcherList', () {
    testWidgets('Settings button opens the settings page', (tester) async {
      // The test font is wider than Roboto and overflows the fixed-width menu.
      tester.platformDispatcher.textScaleFactorTestValue = 0.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(buildSwitcherUnderTest());
      await tester.tap(find.text('Open menu'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Profile page'), findsOneWidget);
      expect(find.text('Settings'), findsNothing);
    });

    testWidgets('Invite closes the menu and opens the invite dialog', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 0.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(buildSwitcherUnderTest());
      await tester.tap(find.text('Open menu'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Invite'));
      await tester.pumpAndSettle();

      expect(find.byType(WorkspaceSwitcherList), findsNothing);
      expect(find.byType(InviteTeammatesModal), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'renders safe initial without crash when workspace name is empty or starts with emoji',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 0.5;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await tester.pumpWidget(buildEmptySwitcherUnderTest());
        await tester.tap(find.text('Open menu'));
        await tester.pumpAndSettle();

        // Empty name falls back to 'W' without throwing RangeError
        expect(find.text('W'), findsWidgets);
        // Emoji name extracts complete first grapheme '🚀'
        expect(find.text('🚀'), findsOneWidget);
      },
    );

    testWidgets('tells the user when switching organisation fails', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 0.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        buildSwitcherUnderTest(notifier: FailingSwitchNotifier.new),
      );
      await tester.tap(find.text('Open menu'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Globex'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(WorkspaceNotifier.switchErrorMessage), findsOneWidget);
      // Let the toast's timer run out.
      await tester.pump(const Duration(seconds: 10));
    });
  });
}

class FakeEmptyWorkspaceNotifier extends WorkspaceNotifier {
  @override
  WorkspaceState build() => const WorkspaceState(
    workspaces: [
      Workspace(id: '1', name: '', avatar: ''),
      Workspace(id: '2', name: '🚀 Rocket', avatar: ''),
    ],
    selectedWorkspace: Workspace(id: '1', name: '', avatar: ''),
  );
}

Widget buildEmptySwitcherUnderTest() {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const Align(
                  alignment: Alignment.topLeft,
                  child: WorkspaceSwitcherList(),
                ),
              ),
              child: const Text('Open menu'),
            ),
          ),
        ),
      ),
    ],
  );

  return ProviderScope(
    overrides: [workspaceProvider.overrideWith(FakeEmptyWorkspaceNotifier.new)],
    child: MaterialApp.router(routerConfig: router),
  );
}
