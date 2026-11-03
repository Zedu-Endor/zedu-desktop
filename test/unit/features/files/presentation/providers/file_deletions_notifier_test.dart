import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class MockFilesRepository extends Mock implements FilesRepository {}

const _file = WorkspaceFile(id: 'f-1', name: 'logo.png');

void main() {
  late MockFilesRepository repository;
  late ProviderContainer container;

  FileDeletionsNotifier notifier() =>
      container.read(fileDeletionsProvider.notifier);

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
  });

  setUpAll(() => registerFallbackValue(const FilesQuery(view: FilesScope.all)));

  test('deletes the file and reloads the list', () async {
    final done = Completer<Result<void>>();
    when(() => repository.deleteFile('f-1')).thenAnswer((_) => done.future);
    container.listen(filesListProvider, (_, _) {});
    await container.read(filesListProvider.future);
    clearInteractions(repository);

    final pending = notifier().delete(_file);
    expect(container.read(fileDeletionsProvider), {'f-1'});

    done.complete(const Success(null));
    expect(await pending, isNull);
    expect(container.read(fileDeletionsProvider), isEmpty);
    await container.read(filesListProvider.future);
    verify(() => repository.fetchFiles(any())).called(1);
  });

  test('deletes for good when asked', () async {
    when(
      () => repository.deleteFile('f-1', permanent: true),
    ).thenAnswer((_) async => const Success(null));

    expect(await notifier().delete(_file, permanent: true), isNull);
    verify(() => repository.deleteFile('f-1', permanent: true)).called(1);
  });

  test('explains a failed delete', () async {
    when(() => repository.deleteFile('f-1')).thenAnswer(
      (_) async => const Failure(
        ApiFailure(message: 'nope', kind: ApiFailureKind.forbidden),
      ),
    );

    expect(
      await notifier().delete(_file),
      'Could not delete logo.png. You don\'t have permission to do that.',
    );
    expect(container.read(fileDeletionsProvider), isEmpty);
  });
}
