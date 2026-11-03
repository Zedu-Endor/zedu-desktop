import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class MockFilesRepository extends Mock implements FilesRepository {}

const _file = WorkspaceFile(id: 'f-1', name: 'logo.png');

void main() {
  late MockFilesRepository repository;
  late ProviderContainer container;
  late List<String> askedNames;
  String? chosenPath;
  Object? pickerError;

  FileDownloadsNotifier notifier() =>
      container.read(fileDownloadsProvider.notifier);
  Map<String, double?> downloads() => container.read(fileDownloadsProvider);

  void stubDownload(
    Future<Result<void>> Function(void Function(double?)? onProgress) answer,
  ) {
    when(
      () => repository.downloadFile(
        file: any(named: 'file'),
        savePath: any(named: 'savePath'),
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer(
      (invocation) => answer(
        invocation.namedArguments[#onProgress] as void Function(double?)?,
      ),
    );
  }

  setUpAll(() => registerFallbackValue(_file));

  setUp(() {
    repository = MockFilesRepository();
    askedNames = [];
    chosenPath = '/Users/ada/Downloads/logo.png';
    pickerError = null;
    container = ProviderContainer(
      overrides: [
        filesRepositoryProvider.overrideWithValue(repository),
        saveLocationPickerProvider.overrideWithValue((name) async {
          askedNames.add(name);
          if (pickerError != null) throw pickerError!;
          return chosenPath;
        }),
      ],
    );
    addTearDown(container.dispose);
  });

  test('saves the file where the person chose', () async {
    stubDownload((_) async => const Success(null));

    final outcome = await notifier().download(_file);

    expect(askedNames, ['logo.png']);
    expect(outcome.status, FileDownloadStatus.saved);
    expect(outcome.path, '/Users/ada/Downloads/logo.png');
    verify(
      () => repository.downloadFile(
        file: _file,
        savePath: '/Users/ada/Downloads/logo.png',
        onProgress: any(named: 'onProgress'),
      ),
    ).called(1);
    expect(downloads(), isEmpty);
  });

  test('does nothing when the save dialog is cancelled', () async {
    chosenPath = null;

    final outcome = await notifier().download(_file);

    expect(outcome.status, FileDownloadStatus.cancelled);
    verifyNever(
      () => repository.downloadFile(
        file: any(named: 'file'),
        savePath: any(named: 'savePath'),
        onProgress: any(named: 'onProgress'),
      ),
    );
  });

  test('tracks progress while the file downloads', () async {
    final done = Completer<Result<void>>();
    void Function(double?)? report;
    stubDownload((onProgress) {
      report = onProgress;
      return done.future;
    });

    final pending = notifier().download(_file);
    await pumpEventQueue();
    expect(downloads(), {'f-1': 0.0});

    report!(0.42);
    expect(downloads(), {'f-1': 0.42});
    report!(null);
    expect(downloads(), {'f-1': null});

    // A second tap while it downloads does not start another download.
    final again = await notifier().download(_file);
    expect(again.status, FileDownloadStatus.cancelled);

    done.complete(const Success(null));
    await pending;
    expect(downloads(), isEmpty);
  });

  test('explains a failed download', () async {
    stubDownload(
      (_) async => const Failure(
        ApiFailure(message: 'offline', kind: ApiFailureKind.network),
      ),
    );

    final outcome = await notifier().download(_file);

    expect(outcome.status, FileDownloadStatus.failed);
    expect(
      outcome.message,
      'Could not download logo.png. '
      'No internet connection. Check your network and try again.',
    );
    expect(downloads(), isEmpty);
  });

  test('hides raw errors behind a plain retry message', () async {
    stubDownload(
      (_) async => const Failure(
        ApiFailure(message: 'FileSystemException: Permission denied'),
      ),
    );

    final outcome = await notifier().download(_file);

    expect(outcome.message, 'Could not download logo.png. Please try again.');
  });

  test('fails clearly when the save dialog cannot open', () async {
    pickerError = Exception('missing entitlement');

    final outcome = await notifier().download(_file);

    expect(outcome.status, FileDownloadStatus.failed);
    expect(outcome.message, contains('save dialog could not open'));
  });
}
