import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class MockFilesRepository extends Mock implements FilesRepository {}

const _file = WorkspaceFile(id: 'f-1', name: 'logo.png');

void main() {
  late MockFilesRepository repository;
  late ProviderContainer container;

  PinnedFilesNotifier notifier() =>
      container.read(pinnedFilesProvider.notifier);

  setUp(() {
    repository = MockFilesRepository();
    container = ProviderContainer(
      overrides: [
        currentOrgIdProvider.overrideWithValue('org-1'),
        filesRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
  });

  test('loads the pins kept on the server', () async {
    when(
      () => repository.fetchPinnedFileIds(),
    ).thenAnswer((_) async => const Success({'f-1'}));

    expect(await container.read(pinnedFilesProvider.future), {'f-1'});
    expect(notifier().isPinned('f-1'), isTrue);
  });

  test('without the pins, nothing is marked pinned', () async {
    when(() => repository.fetchPinnedFileIds()).thenAnswer(
      (_) async => const Failure(
        ApiFailure(message: 'offline', kind: ApiFailureKind.network),
      ),
    );

    expect(await container.read(pinnedFilesProvider.future), isEmpty);
  });

  test('pins, then unpins', () async {
    when(
      () => repository.fetchPinnedFileIds(),
    ).thenAnswer((_) async => const Success({}));
    when(
      () => repository.pinFile('f-1'),
    ).thenAnswer((_) async => const Success(null));
    when(
      () => repository.unpinFile('f-1'),
    ).thenAnswer((_) async => const Success(null));
    await container.read(pinnedFilesProvider.future);

    expect(await notifier().toggle(_file), isNull);
    expect(container.read(pinnedFilesProvider).value, {'f-1'});

    expect(await notifier().toggle(_file), isNull);
    expect(container.read(pinnedFilesProvider).value, isEmpty);
    verifyInOrder([
      () => repository.pinFile('f-1'),
      () => repository.unpinFile('f-1'),
    ]);
  });

  test(
    'marks the file at once and undoes it when the server refuses',
    () async {
      when(
        () => repository.fetchPinnedFileIds(),
      ).thenAnswer((_) async => const Success({'f-1'}));
      final unpin = Completer<Result<void>>();
      when(() => repository.unpinFile('f-1')).thenAnswer((_) => unpin.future);
      await container.read(pinnedFilesProvider.future);

      final pending = notifier().toggle(_file);
      expect(container.read(pinnedFilesProvider).value, isEmpty);
      // A second click while the first is in flight does nothing.
      expect(await notifier().toggle(_file), isNull);

      unpin.complete(
        const Failure<void>(
          ApiFailure(message: 'offline', kind: ApiFailureKind.network),
        ),
      );

      expect(
        await pending,
        'Could not unpin logo.png. '
        'No internet connection. Check your network and try again.',
      );
      expect(container.read(pinnedFilesProvider).value, {'f-1'});
      verify(() => repository.unpinFile('f-1')).called(1);
    },
  );
}
