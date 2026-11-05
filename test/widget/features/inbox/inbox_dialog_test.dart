import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../helpers/helpers.dart';

class MockInboxRepository extends Mock implements InboxRepository {}

class FakeWorkspaceNotifier extends WorkspaceNotifier {
  FakeWorkspaceNotifier(this._initial);
  final WorkspaceState _initial;

  @override
  WorkspaceState build() => _initial;
}

void main() {
  late MockInboxRepository repository;

  const alpha = Workspace(id: 'ws-alpha', name: 'Alpha', avatar: '');
  const beta = Workspace(id: 'ws-beta', name: 'Beta', avatar: '');

  InboxItem item({
    required String title,
    required Workspace workspace,
    int unread = 0,
    int minutesAgo = 0,
  }) {
    return InboxItem(
      workspaceId: workspace.id,
      workspaceName: workspace.name,
      channelId: 'ch-$title',
      title: title,
      preview: 'hello from $title',
      unreadCount: unread,
      lastActivityAt: DateTime.utc(
        2026,
        11,
        5,
        12,
      ).subtract(Duration(minutes: minutesAgo)),
      kind: InboxItemKind.directMessage,
      participantId: 'user-$title',
    );
  }

  setUp(() {
    repository = MockInboxRepository();
  });

  Future<void> pumpInbox(WidgetTester tester, InboxSnapshot snapshot) async {
    when(() => repository.load(any())).thenAnswer((_) async => snapshot);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inboxRepositoryProvider.overrideWithValue(repository),
          workspaceProvider.overrideWith(
            () => FakeWorkspaceNotifier(
              const WorkspaceState(
                workspaces: [alpha, beta],
                selectedWorkspace: alpha,
              ),
            ),
          ),
        ],
        child: buildTestMaterialApp(const InboxDialog()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists conversations from every workspace with their workspace', (
    tester,
  ) async {
    await pumpInbox(
      tester,
      InboxSnapshot(
        items: [
          item(title: 'Ada', workspace: alpha, unread: 2),
          item(title: 'Grace', workspace: beta, minutesAgo: 10),
        ],
      ),
    );

    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Grace'), findsOneWidget);
    // Each row names the workspace it came from.
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
  });

  testWidgets('the unread filter hides conversations that are read', (
    tester,
  ) async {
    await pumpInbox(
      tester,
      InboxSnapshot(
        items: [
          item(title: 'Ada', workspace: alpha, unread: 2),
          item(title: 'Grace', workspace: beta, minutesAgo: 10),
        ],
      ),
    );

    expect(find.text('Grace'), findsOneWidget);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Grace'), findsNothing);
    expect(find.text('Unread only'), findsOneWidget);
  });

  testWidgets('names a workspace that could not be read, and shows the rest', (
    tester,
  ) async {
    await pumpInbox(
      tester,
      InboxSnapshot(
        items: [item(title: 'Ada', workspace: alpha)],
        failedWorkspaces: const ['Beta'],
      ),
    );

    expect(find.textContaining('Could not read Beta'), findsOneWidget);
    expect(find.text('Ada'), findsOneWidget);
  });

  testWidgets('says so when there is nothing to catch up on', (tester) async {
    await pumpInbox(tester, const InboxSnapshot());

    expect(find.text('Your inbox is empty'), findsOneWidget);
  });
}
