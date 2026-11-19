import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

const _workspaceA = Workspace(id: 'org-a', name: 'Workspace A', avatar: '');
const _workspaceB = Workspace(id: 'org-b', name: 'Workspace B', avatar: '');

class _FakeWorkspaceNotifier extends WorkspaceNotifier {
  @override
  WorkspaceState build() =>
      const WorkspaceState(selectedWorkspace: _workspaceA);

  void select(Workspace workspace) =>
      state = WorkspaceState(selectedWorkspace: workspace);
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

  String fieldText(WidgetTester tester) =>
      tester.widget<EditableText>(find.byType(EditableText)).controller.text;

  String search() => container.read(filesProvider).search;

  Future<void> switchWorkspace(WidgetTester tester) async {
    (container.read(workspaceProvider.notifier) as _FakeWorkspaceNotifier)
        .select(_workspaceB);
    await tester.pump();
  }

  testWidgets('clears the box when a workspace switch resets the search', (
    tester,
  ) async {
    await pumpToolbar(tester);
    await tester.enterText(find.byType(TextField), 'budget');
    await tester.pump(const Duration(milliseconds: 400));
    expect(search(), 'budget');

    await switchWorkspace(tester);

    expect(search(), isEmpty);
    expect(fieldText(tester), isEmpty);
  });

  testWidgets('drops typing still waiting to be reported when reset', (
    tester,
  ) async {
    await pumpToolbar(tester);
    await tester.enterText(find.byType(TextField), 'budget');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), 'budget plan');

    await switchWorkspace(tester);
    await tester.pump(const Duration(milliseconds: 400));

    expect(search(), isEmpty);
    expect(fieldText(tester), isEmpty);
  });

  testWidgets('keeps what is being typed when an earlier search lands', (
    tester,
  ) async {
    await pumpToolbar(tester);
    await tester.enterText(find.byType(TextField), 'bud');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), 'budget');
    await tester.pump();

    expect(search(), 'bud');
    expect(fieldText(tester), 'budget');

    await tester.pump(const Duration(milliseconds: 400));
    expect(search(), 'budget');
    expect(fieldText(tester), 'budget');
  });

  testWidgets('shows the current search when the box is created', (
    tester,
  ) async {
    await pumpToolbar(tester);
    container.read(filesProvider.notifier).setSearch('budget');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: buildTestMaterialApp(const Scaffold(body: FilesToolbar())),
      ),
    );

    expect(fieldText(tester), 'budget');
  });

  testWidgets('shows the active sort order after it is selected', (
    tester,
  ) async {
    await pumpToolbar(tester);

    await tester.tap(find.byTooltip('Sort'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oldest to newest').last);
    await tester.pumpAndSettle();

    expect(find.text('Oldest to newest'), findsOneWidget);
  });

  testWidgets(
    'shows clear button only when field has text and hides when empty',
    (tester) async {
      await pumpToolbar(tester);
      expect(find.byTooltip('Clear search'), findsNothing);

      await tester.enterText(find.byType(TextField), 'budget');
      await tester.pump();
      expect(find.byTooltip('Clear search'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(find.byTooltip('Clear search'), findsNothing);
    },
  );

  testWidgets(
    'tapping clear button empties input and updates search immediately',
    (tester) async {
      await pumpToolbar(tester);
      await tester.enterText(find.byType(TextField), 'budget');
      await tester.pump(const Duration(milliseconds: 400));
      expect(search(), 'budget');

      await tester.tap(find.byTooltip('Clear search'));
      await tester.pump();

      expect(fieldText(tester), isEmpty);
      expect(search(), isEmpty);
      expect(find.byTooltip('Clear search'), findsNothing);
    },
  );

  testWidgets(
    'clearing search leaves type and date modified filters unchanged',
    (tester) async {
      await pumpToolbar(tester);
      container.read(filesProvider.notifier).setCategory(FileCategory.images);
      container
          .read(filesProvider.notifier)
          .setDateModified(DateModifiedFilter.last30Days);
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'report');
      await tester.pump(const Duration(milliseconds: 400));

      expect(container.read(filesProvider).category, FileCategory.images);
      expect(
        container.read(filesProvider).dateModified,
        DateModifiedFilter.last30Days,
      );
      expect(container.read(filesProvider).search, 'report');
      expect(find.byTooltip('Clear search'), findsOneWidget);

      await tester.tap(find.byTooltip('Clear search'));
      await tester.pump();

      expect(container.read(filesProvider).search, isEmpty);
      expect(container.read(filesProvider).category, FileCategory.images);
      expect(
        container.read(filesProvider).dateModified,
        DateModifiedFilter.last30Days,
      );
    },
  );

  testWidgets('clear icon uses design system colors and accessible tooltip', (
    tester,
  ) async {
    await pumpToolbar(tester);
    final colors = tester.element(find.byType(FilesToolbar)).colors;

    await tester.enterText(find.byType(TextField), 'query');
    await tester.pump();

    final iconFinder = find.widgetWithIcon(IconButton, Icons.close);
    expect(iconFinder, findsOneWidget);
    final icon = tester.widget<Icon>(
      find.descendant(of: iconFinder, matching: find.byType(Icon)),
    );
    expect(icon.color, colors.textHint);
    expect(icon.size, 16);
  });

  testWidgets('normal typing preserves debounce behavior', (tester) async {
    await pumpToolbar(tester);
    await tester.enterText(find.byType(TextField), 'notes');
    await tester.pump(const Duration(milliseconds: 200));
    expect(search(), isEmpty);

    await tester.pump(const Duration(milliseconds: 200));
    expect(search(), 'notes');
  });
}
