import 'dart:io';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Files created or inspected by the composer. Picked files are never deleted.
class ComposerFileStore {
  ComposerFileStore({Directory? temporaryDirectory, Set<String>? recordedPaths})
    : _temporaryDirectory = temporaryDirectory,
      _recordedPaths = recordedPaths ?? appRecordedPaths;

  final Directory? _temporaryDirectory;
  final Set<String> _recordedPaths;

  Directory get _temp => _temporaryDirectory ?? Directory.systemTemp;

  Result<String> newRecordingPath() {
    try {
      return Success(
        '${_temp.path}${Platform.pathSeparator}zedu-voice-${DateTime.now().microsecondsSinceEpoch}.m4a',
      );
    } catch (error) {
      return Failure(
        ApiFailure(message: 'Could not create a recording path: $error'),
      );
    }
  }

  void trackRecording(String path) => _recordedPaths.add(path);

  Future<Result<void>> deleteRecording(String? path) async {
    if (path == null || !_recordedPaths.contains(path)) {
      return const Success(null);
    }
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
      _recordedPaths.remove(path);
      return const Success(null);
    } catch (error) {
      // Keep ownership after a failure so cleanup can be retried later.
      return Failure(
        ApiFailure(message: 'Could not remove a recording: $error'),
      );
    }
  }

  Future<Result<bool>> exists(String path) async {
    try {
      return Success(await File(path).exists());
    } catch (error) {
      return Failure(
        ApiFailure(message: 'Could not inspect an attachment: $error'),
      );
    }
  }

  Future<Result<String>> writeTemporaryFile(
    String name,
    List<int> bytes,
  ) async {
    try {
      final file = File('${_temp.path}${Platform.pathSeparator}$name');
      await file.writeAsBytes(bytes);
      return Success(file.path);
    } catch (error) {
      return Failure(
        ApiFailure(message: 'Could not save a pasted image: $error'),
      );
    }
  }
}

final composerFileStoreProvider = Provider<ComposerFileStore>(
  (ref) => ComposerFileStore(),
);
