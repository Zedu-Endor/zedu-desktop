import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class _Workspace extends WorkspaceNotifier {
  @override
  WorkspaceState build() => const WorkspaceState(
    selectedWorkspace: Workspace(id: 'org', name: 'Org', avatar: ''),
  );
}

void main() {
  testWidgets('denied webhook permission does not render secret controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workspaceProvider.overrideWith(_Workspace.new),
          webhookManagementPermissionProvider.overrideWith(
            (ref) async => false,
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: WebhookManagementSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('do not have permission'), findsOneWidget);
    expect(find.text('Copy URL'), findsNothing);
    expect(find.text('Create webhook'), findsNothing);
  });
}
