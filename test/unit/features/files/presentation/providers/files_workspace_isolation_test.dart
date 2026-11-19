import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class _Workspace extends Notifier<String> {
  @override
  String build() => 'workspace-a';

  void select(String id) => state = id;
}

final _workspaceProvider = NotifierProvider<_Workspace, String>(_Workspace.new);

class _Repository extends Fake implements FilesRepository {
  final String Function() workspace;
  final files = <String, Completer<Result<FilesPage>>>{};
  final folders = <String, Completer<Result<FoldersPage>>>{};

  _Repository(this.workspace);

  @override
  Future<Result<FilesPage>> fetchFiles(FilesQuery query) {
    final result = Completer<Result<FilesPage>>();
    files[workspace()] = result;
    return result.future;
  }

  @override
  Future<Result<FoldersPage>> fetchFolders({
    required FilesScope view,
    String? parentId,
    int page = 1,
  }) {
    final result = Completer<Result<FoldersPage>>();
    folders[workspace()] = result;
    return result.future;
  }

  void succeed(String id) {
    files[id]!.complete(
      Success(
        FilesPage(
          files: [WorkspaceFile(id: id, name: id)],
        ),
      ),
    );
    folders[id]!.complete(
      Success(
        FoldersPage(
          folders: [FileFolder(id: id, name: id)],
        ),
      ),
    );
  }
}

String _visible<T>(AsyncValue<T> state) => state.when(
  data: (_) => 'data',
  loading: () => 'loading',
  error: (_, _) => 'error',
);

void main() {
  late ProviderContainer container;
  late _Repository repository;

  setUp(() {
    repository = _Repository(() => container.read(_workspaceProvider));
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        currentOrgIdProvider.overrideWith(
          (ref) => ref.watch(_workspaceProvider),
        ),
        filesRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    container.listen(filesListProvider, (_, _) {});
    container.listen(foldersListProvider, (_, _) {});
  });

  Future<void> finish(String workspace) async {
    repository.succeed(workspace);
    await container.read(filesListProvider.future);
    await container.read(foldersListProvider.future);
  }

  Future<void> switchToB() async {
    container.read(_workspaceProvider.notifier).select('workspace-b');
    await container.pump();
  }

  test(
    'equal root filters refetch files and folders in the new workspace',
    () async {
      await finish('workspace-a');
      final originalQuery = container.read(filesProvider).query;

      await switchToB();

      expect(container.read(filesProvider).query, originalQuery);
      expect(repository.files.keys, ['workspace-a', 'workspace-b']);
      expect(repository.folders.keys, ['workspace-a', 'workspace-b']);
      // This is how FilesView renders AsyncValue: dependency reloads must show
      // loading, even when Riverpod retains the previous value internally.
      expect(_visible(container.read(filesListProvider)), 'loading');
      expect(_visible(container.read(foldersListProvider)), 'loading');
      await finish('workspace-b');
      expect(
        container.read(filesListProvider).requireValue.files.single.id,
        'workspace-b',
      );
      expect(
        container.read(foldersListProvider).requireValue.folders.single.id,
        'workspace-b',
      );
    },
  );

  test('a new-workspace failure shows an error rather than old rows', () async {
    await finish('workspace-a');
    await switchToB();
    repository.files['workspace-b']!.complete(
      const Failure(ApiFailure(message: 'offline')),
    );
    repository.folders['workspace-b']!.complete(
      const Failure(ApiFailure(message: 'offline')),
    );
    await expectLater(
      container.read(filesListProvider.future),
      throwsA(isA<ApiFailure>()),
    );
    await expectLater(
      container.read(foldersListProvider.future),
      throwsA(isA<ApiFailure>()),
    );
    await container.pump();

    expect(_visible(container.read(filesListProvider)), 'error');
    expect(_visible(container.read(foldersListProvider)), 'error');
  });

  test(
    'late responses from the old workspace cannot overwrite the new one',
    () async {
      await switchToB();
      await finish('workspace-b');
      repository.succeed('workspace-a');
      await container.pump();

      expect(
        container.read(filesListProvider).requireValue.files.single.id,
        'workspace-b',
      );
      expect(
        container.read(foldersListProvider).requireValue.folders.single.id,
        'workspace-b',
      );
    },
  );
}
