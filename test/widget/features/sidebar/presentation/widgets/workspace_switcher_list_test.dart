import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class FakeWorkspaceNotifier extends WorkspaceNotifier {
  FakeWorkspaceNotifier({WorkspaceState? customState})
    : _customState = customState;
  final WorkspaceState? _customState;

  @override
  WorkspaceState build() {
    return _customState ??
        const WorkspaceState(
          workspaces: [
            Workspace(
              id: '1',
              name: 'Test Workspace',
              avatar: '',
              unreadCount: 0,
              membersCount: 10,
            ),
          ],
          selectedWorkspace: Workspace(
            id: '1',
            name: 'Test Workspace',
            avatar: '',
            unreadCount: 0,
            membersCount: 10,
          ),
        );
  }
}

Widget buildWorkspaceSwitcherUnderTest({
  FakeWorkspaceNotifier? workspaceNotifier,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () {
                showGeneralDialog<void>(
                  context: context,
                  barrierDismissible: true,
                  barrierLabel: 'WorkspaceSwitcher',
                  pageBuilder: (context, anim1, anim2) {
                    return const Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: EdgeInsets.only(top: 60, left: 16),
                        child: WorkspaceSwitcherList(),
                      ),
                    );
                  },
                );
              },
              child: const Text('Open Switcher'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: AppRouter.profile,
        builder: (context, state) =>
            const Scaffold(body: Text('Profile Settings Screen')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      workspaceProvider.overrideWith(
        () => workspaceNotifier ?? FakeWorkspaceNotifier(),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('WorkspaceSwitcherList', () {
    testWidgets('renders current workspace information and settings button', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildWorkspaceSwitcherUnderTest());
      await tester.pumpAndSettle();

      // Open the workspace switcher dialog
      await tester.tap(find.text('Open Switcher'));
      await tester.pumpAndSettle();

      expect(find.text('Test Workspace'), findsNWidgets(2));
      expect(find.text('10 members'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Invite'), findsOneWidget);
    });

    testWidgets('tapping Settings button navigates to AppRouter.profile', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildWorkspaceSwitcherUnderTest());
      await tester.pumpAndSettle();

      // Open dialog
      await tester.tap(find.text('Open Switcher'));
      await tester.pumpAndSettle();

      // Tap Settings button
      final settingsButton = find.text('Settings');
      expect(settingsButton, findsOneWidget);
      await tester.tap(settingsButton);
      await tester.pumpAndSettle();

      // Verify navigation to profile route and dialog dismissal
      expect(find.text('Profile Settings Screen'), findsOneWidget);
      expect(find.byType(WorkspaceSwitcherList), findsNothing);
    });
  });
}
