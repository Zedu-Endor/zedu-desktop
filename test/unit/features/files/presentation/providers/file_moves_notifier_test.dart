import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class MockFilesRepository extends Mock implements FilesRepository {}

const _file = WorkspaceFile(id: 'f-1', name: 'logo.png');
const _docs = FileFolder(id: 'docs', name: 'docs');

void main() {
  late MockFilesRepository repository;
  late ProviderContainer container;

  FileMovesNotifier notifier() => container.read(fileMovesProvider.notifier);

  setUpAll(() {
    registerFallbackValue(const FilesQuery(view: FilesScope.all));
    registerFallbackValue(FilesScope.all);
  });

  setUp(() {
    repository = MockFilesRepository();
    container = ProviderContainer(
      overrides: [
        currentOrgIdProvider.overrideWithValue('org-1'),
        filesRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    when(
      () => repository.fetchFiles(any()),
    ).thenAnswer((_) async => const Success(FilesPage(files: [])));
    when(
      () => repository.fetchFolders(
        view: any(named: 'view'),
        parentId: any(named: 'parentId'),
        page: any(named: 'page'),
      ),
    ).thenAnswer((_) async => const Success(FoldersPage(folders: [_docs])));
  });

  test('moves the file and reloads the files and folders', () async {
    when(
      () => repository.moveFile('f-1', 'docs'),
    ).thenAnswer((_) async => const Success(null));
    container
      ..listen(filesListProvider, (_, _) {})
      ..listen(foldersListProvider, (_, _) {});
    await container.read(filesListProvider.future);
    await container.read(foldersListProvider.future);
    clearInteractions(repository);

    expect(await notifier().move(_file, _docs), isNull);
    expect(container.read(fileMovesProvider), isEmpty);

    await container.read(filesListProvider.future);
    await container.read(foldersListProvider.future);
    verify(() => repository.fetchFiles(any())).called(1);
    verify(
      () => repository.fetchFolders(
        view: any(named: 'view'),
        parentId: any(named: 'parentId'),
        page: any(named: 'page'),
      ),
    ).called(1);
  });

  test('explains a failed move', () async {
    when(() => repository.moveFile('f-1', 'docs')).thenAnswer(
      (_) async => const Failure(
        ApiFailure(message: 'offline', kind: ApiFailureKind.network),
      ),
    );

    expect(
      await notifier().move(_file, _docs),
      'Could not move logo.png. '
      'No internet connection. Check your network and try again.',
    );
    expect(container.read(fileMovesProvider), isEmpty);
  });

  test('the move targets include folders from every page', () async {
    const reports = FileFolder(id: 'reports', name: 'reports');
    when(
      () => repository.fetchFolders(view: FilesScope.all, page: 1),
    ).thenAnswer(
      (_) async => const Success(FoldersPage(folders: [_docs], totalPages: 2)),
    );
    when(
      () => repository.fetchFolders(view: FilesScope.all, page: 2),
    ).thenAnswer(
      (_) async => const Success(
        FoldersPage(folders: [reports], currentPage: 2, totalPages: 2),
      ),
    );

    final folders = await container.read(
      moveTargetFoldersProvider(null).future,
    );

    expect(folders.map((f) => f.id), ['docs', 'reports']);
  });
}
