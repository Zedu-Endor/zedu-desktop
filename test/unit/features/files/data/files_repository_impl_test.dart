import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../helpers/helpers.dart';

class MockFilesRemoteDataSource extends Mock implements FilesRemoteDataSource {}

const _withLink = WorkspaceFile(
  id: 'f-1',
  name: 'logo.png',
  link: 'https://cdn.zedu.test/logo.png',
);
const _withoutLink = WorkspaceFile(id: 'f-2', name: 'spec.pdf');

void main() {
  late MockFilesRemoteDataSource remote;
  late FilesRepositoryImpl repository;

  void stubDownload({void Function(void Function(int, int)? onProgress)? run}) {
    when(
      () => remote.downloadFile(
        url: any(named: 'url'),
        savePath: any(named: 'savePath'),
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer((invocation) async {
      run?.call(
        invocation.namedArguments[#onProgress] as void Function(int, int)?,
      );
    });
  }

  setUp(() {
    remote = MockFilesRemoteDataSource();
    repository = FilesRepositoryImpl(remoteDataSource: remote);
  });

  test('downloads from the link the list gave', () async {
    stubDownload();

    final result = await repository.downloadFile(
      file: _withLink,
      savePath: '/tmp/logo.png',
    );

    expect(result, isA<Success<void>>());
    verifyNever(() => remote.fetchFileLink(any()));
    verify(
      () => remote.downloadFile(
        url: 'https://cdn.zedu.test/logo.png',
        savePath: '/tmp/logo.png',
        onProgress: any(named: 'onProgress'),
      ),
    ).called(1);
  });

  test('asks the server for the link when the list had none', () async {
    when(
      () => remote.fetchFileLink('f-2'),
    ).thenAnswer((_) async => 'https://cdn.zedu.test/spec.pdf');
    stubDownload();

    final result = await repository.downloadFile(
      file: _withoutLink,
      savePath: '/tmp/spec.pdf',
    );

    expect(result, isA<Success<void>>());
    verify(
      () => remote.downloadFile(
        url: 'https://cdn.zedu.test/spec.pdf',
        savePath: '/tmp/spec.pdf',
        onProgress: any(named: 'onProgress'),
      ),
    ).called(1);
  });

  test('fails without downloading when there is no link at all', () async {
    when(() => remote.fetchFileLink('f-2')).thenAnswer((_) async => '');

    final result = await repository.downloadFile(
      file: _withoutLink,
      savePath: '/tmp/spec.pdf',
    );

    expect(
      result,
      isA<Failure<void>>().having(
        (f) => f.error.friendlyMessage,
        'message',
        'This file has no download link.',
      ),
    );
    verifyNever(
      () => remote.downloadFile(
        url: any(named: 'url'),
        savePath: any(named: 'savePath'),
        onProgress: any(named: 'onProgress'),
      ),
    );
  });

  test(
    'reports progress as a share, or null when the size is unknown',
    () async {
      stubDownload(
        run: (onProgress) {
          onProgress!(25, 100);
          onProgress(10, -1);
        },
      );
      final progress = <double?>[];

      await repository.downloadFile(
        file: _withLink,
        savePath: '/tmp/logo.png',
        onProgress: progress.add,
      );

      expect(progress, [0.25, null]);
    },
  );

  test('returns the failure when the download fails', () async {
    when(
      () => remote.downloadFile(
        url: any(named: 'url'),
        savePath: any(named: 'savePath'),
        onProgress: any(named: 'onProgress'),
      ),
    ).thenThrow(
      const ApiFailure(message: 'offline', kind: ApiFailureKind.network),
    );

    final result = await repository.downloadFile(
      file: _withLink,
      savePath: '/tmp/logo.png',
    );

    expect(
      result,
      isA<Failure<void>>().having(
        (f) => f.error.kind,
        'kind',
        ApiFailureKind.network,
      ),
    );
  });

  group('deleteFile', () {
    test('passes the request on and succeeds', () async {
      when(
        () => remote.deleteFile('f-1', permanent: true),
      ).thenAnswer((_) async {});

      final result = await repository.deleteFile('f-1', permanent: true);

      expect(result, isA<Success<void>>());
      verify(() => remote.deleteFile('f-1', permanent: true)).called(1);
    });

    test('returns the failure when the server refuses', () async {
      when(() => remote.deleteFile('f-1')).thenThrow(
        const ApiFailure(message: 'nope', kind: ApiFailureKind.forbidden),
      );

      final result = await repository.deleteFile('f-1');

      expect(
        result,
        isA<Failure<void>>().having(
          (f) => f.error.kind,
          'kind',
          ApiFailureKind.forbidden,
        ),
      );
    });
  });

  group('renameFile', () {
    test('passes the request on and succeeds', () async {
      when(
        () => remote.renameFile('f-1', 'brand.png'),
      ).thenAnswer((_) async {});

      expect(
        await repository.renameFile('f-1', 'brand.png'),
        isA<Success<void>>(),
      );
    });

    test('returns the failure when the server refuses', () async {
      when(() => remote.renameFile('f-1', 'brand.png')).thenThrow(
        const ApiFailure(message: 'Name taken', kind: ApiFailureKind.client),
      );

      final result = await repository.renameFile('f-1', 'brand.png');

      expect(
        result,
        isA<Failure<void>>().having(
          (f) => f.error.message,
          'message',
          'Name taken',
        ),
      );
    });
  });
}
