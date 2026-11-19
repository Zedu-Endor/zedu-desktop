import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class MockFilesRepository extends Mock implements FilesRepository {}

const _file = WorkspaceFile(id: 'f-1', name: 'logo.png');

void main() {
  late MockFilesRepository repository;
  late ProviderContainer container;

  FileRenamesNotifier notifier() =>
      container.read(fileRenamesProvider.notifier);

  setUpAll(() => registerFallbackValue(const FilesQuery(view: FilesScope.all)));

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

  test('renames the file, trimmed, and reloads the list', () async {
    final done = Completer<Result<void>>();
    when(
      () => repository.renameFile('f-1', 'brand.png'),
    ).thenAnswer((_) => done.future);
    container.listen(filesListProvider, (_, _) {});
    await container.read(filesListProvider.future);
    clearInteractions(repository);

    final pending = notifier().rename(_file, '  brand.png ');
    expect(container.read(fileRenamesProvider), {'f-1'});

    done.complete(const Success(null));
    expect(await pending, isNull);
    expect(container.read(fileRenamesProvider), isEmpty);
    await container.read(filesListProvider.future);
    verify(() => repository.fetchFiles(any())).called(1);
  });

  test('does not call the server for the same or an empty name', () async {
    expect(await notifier().rename(_file, 'logo.png'), isNull);
    expect(await notifier().rename(_file, '  '), 'Enter a file name.');
    verifyNever(() => repository.renameFile(any(), any()));
  });

  test('explains a failed rename', () async {
    when(() => repository.renameFile('f-1', 'brand.png')).thenAnswer(
      (_) async => const Failure(
        ApiFailure(message: 'offline', kind: ApiFailureKind.network),
      ),
    );

    expect(
      await notifier().rename(_file, 'brand.png'),
      'Could not rename logo.png. '
      'No internet connection. Check your network and try again.',
    );
    expect(container.read(fileRenamesProvider), isEmpty);
  });

  test('cleans up state if renameFile throws an exception', () async {
    when(
      () => repository.renameFile('f-1', 'brand.png'),
    ).thenThrow(Exception('Connection timed out'));

    expect(
      () => notifier().rename(_file, 'brand.png'),
      throwsA(isA<Exception>()),
    );
    expect(container.read(fileRenamesProvider), isEmpty);
  });
}
