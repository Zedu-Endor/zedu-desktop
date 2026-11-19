import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class _MockChannelRepository extends Mock implements ChannelRepository {}

class _FakeWorkspaceNotifier extends WorkspaceNotifier {
  @override
  WorkspaceState build() => const WorkspaceState(
    selectedWorkspace: Workspace(id: 'org-1', name: 'Workspace A', avatar: ''),
  );
}

Channel _channel(String name, {bool archived = false}) => Channel(
  id: 'channel-$name',
  name: name,
  description: '',
  organisationId: 'org-1',
  ownerId: 'user-1',
  archived: archived,
);

void main() {
  late _MockChannelRepository repository;

  setUp(() {
    repository = _MockChannelRepository();
    when(
      () => repository.fetchChannels(any()),
    ).thenAnswer((_) async => Success([_channel('general')]));
  });

  Future<void> pumpArchivedTab(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          channelRepositoryProvider.overrideWithValue(repository),
          workspaceProvider.overrideWith(_FakeWorkspaceNotifier.new),
        ],
        child: buildTestMaterialApp(
          const Scaffold(body: ChannelDirectoryView()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archived'));
    await tester.pumpAndSettle();
  }

  testWidgets('lists the archived channels from the server', (tester) async {
    when(() => repository.fetchArchivedChannels(any())).thenAnswer(
      (_) async => Success([_channel('old-project', archived: true)]),
    );

    await pumpArchivedTab(tester);

    verify(() => repository.fetchArchivedChannels('org-1')).called(1);
    expect(find.text('old-project'), findsOneWidget);
    expect(find.text('general'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Unarchive'), findsOneWidget);
  });

  testWidgets('Unarchive moves the channel back to the channel list', (
    tester,
  ) async {
    var archived = [_channel('old-project', archived: true)];
    when(
      () => repository.fetchArchivedChannels(any()),
    ).thenAnswer((_) async => Success(archived));
    when(() => repository.archiveChannel(any(), any())).thenAnswer((_) async {
      archived = [];
      return const Success<void>(null);
    });

    await pumpArchivedTab(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Unarchive'));
    await tester.pumpAndSettle();

    verify(() => repository.archiveChannel('channel-old-project', false));
    expect(find.text('#old-project was unarchived'), findsOneWidget);
    expect(find.text('No archived channels.'), findsOneWidget);

    await tester.tap(find.text('Channels'));
    await tester.pumpAndSettle();
    expect(find.text('old-project'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a forbidden unarchive keeps the channel and says who can', (
    tester,
  ) async {
    when(() => repository.fetchArchivedChannels(any())).thenAnswer(
      (_) async => Success([_channel('old-project', archived: true)]),
    );
    when(() => repository.archiveChannel(any(), any())).thenAnswer(
      (_) async => const Failure<void>(
        ApiFailure(message: 'unauthorized', kind: ApiFailureKind.forbidden),
      ),
    );

    await pumpArchivedTab(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Unarchive'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Only the channel owner or an admin can unarchive #old-project.',
      ),
      findsOneWidget,
    );
    expect(find.text('old-project'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a failed load shows Retry', (tester) async {
    when(
      () => repository.fetchArchivedChannels(any()),
    ).thenAnswer((_) async => const Failure(ApiFailure(message: 'offline')));

    await pumpArchivedTab(tester);

    expect(find.text("Couldn't load archived channels"), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
