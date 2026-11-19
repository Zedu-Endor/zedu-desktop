import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class _FakeWorkspaceNotifier extends WorkspaceNotifier {
  @override
  WorkspaceState build() => const WorkspaceState(
    selectedWorkspace: Workspace(id: 'org-a', name: 'Workspace A', avatar: ''),
  );
}

void main() {
  late ProviderContainer container;

  Future<void> pumpToolbar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    container = ProviderContainer(
      overrides: [workspaceProvider.overrideWith(_FakeWorkspaceNotifier.new)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: buildTestMaterialApp(const Scaffold(body: FilesToolbar())),
      ),
    );
  }

  testWidgets('Sort shows the active order and updates from the menu', (
    tester,
  ) async {
    await pumpToolbar(tester);
    final colors = tester.element(find.byType(FilesToolbar)).colors;

    expect(find.text('Newest to oldest'), findsOneWidget);
    expect(find.text('Sort'), findsNothing);
    expect(
      tester.widget<Text>(find.text('Newest to oldest')).style?.color,
      colors.primary,
    );

    await tester.tap(find.byTooltip('Sort'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oldest to newest'));
    await tester.pumpAndSettle();

    expect(find.text('Oldest to newest'), findsOneWidget);
    expect(find.text('Newest to oldest'), findsNothing);
    expect(container.read(filesProvider).sort, FilesSort.oldestFirst);
    expect(
      tester.widget<Text>(find.text('Oldest to newest')).style?.color,
      colors.primary,
    );
  });

  testWidgets('Sort follows a change made outside the control', (tester) async {
    await pumpToolbar(tester);

    container.read(filesProvider.notifier).setSort(FilesSort.oldestFirst);
    await tester.pump();

    expect(find.text('Oldest to newest'), findsOneWidget);
    expect(find.text('Newest to oldest'), findsNothing);
  });
}
