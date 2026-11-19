import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Asks where to save a download, suggesting [fileName]. Returns the chosen
/// path, or null when the person cancels.
typedef SaveLocationPicker = Future<String?> Function(String fileName);

enum FileDownloadStatus { saved, cancelled, failed }

class FileDownloadOutcome {
  const FileDownloadOutcome.saved(String this.path)
    : status = FileDownloadStatus.saved,
      message = null;

  const FileDownloadOutcome.cancelled()
    : status = FileDownloadStatus.cancelled,
      path = null,
      message = null;

  const FileDownloadOutcome.failed(String this.message)
    : status = FileDownloadStatus.failed,
      path = null;

  final FileDownloadStatus status;

  /// Where the file was saved, when [status] is saved.
  final String? path;

  /// What to tell the person, when [status] is failed.
  final String? message;
}

/// Downloads in progress, by file id. The value is the share downloaded,
/// from 0 to 1, or null while the size is unknown.
class FileDownloadsNotifier extends Notifier<Map<String, double?>> {
  @override
  Map<String, double?> build() => const {};

  /// Asks where to save [file], then downloads it there.
  Future<FileDownloadOutcome> download(WorkspaceFile file) async {
    if (state.containsKey(file.id)) {
      return const FileDownloadOutcome.cancelled();
    }

    final String? savePath;
    try {
      savePath = await ref.read(saveLocationPickerProvider)(file.name);
    } catch (_) {
      return FileDownloadOutcome.failed(
        'Could not download ${file.name}. The save dialog could not open.',
      );
    }
    if (savePath == null || savePath.isEmpty) {
      return const FileDownloadOutcome.cancelled();
    }

    state = {...state, file.id: 0};
    final result = await ref
        .read(filesRepositoryProvider)
        .downloadFile(
          file: file,
          savePath: savePath,
          onProgress: (progress) => _setProgress(file.id, progress),
        );
    if (ref.mounted) state = {...state}..remove(file.id);

    return switch (result) {
      Success() => FileDownloadOutcome.saved(savePath),
      Failure(:final error) => FileDownloadOutcome.failed(
        'Could not download ${file.name}. ${_reason(error)}',
      ),
    };
  }

  /// Updates progress in whole percents, so a large file does not rebuild
  /// the table for every chunk.
  void _setProgress(String fileId, double? progress) {
    if (!ref.mounted || !state.containsKey(fileId)) return;
    final previous = state[fileId];
    if (progress != null &&
        previous != null &&
        (progress * 100).floor() == (previous * 100).floor()) {
      return;
    }
    state = {...state, fileId: progress};
  }

  static String _reason(ApiFailure error) => switch (error.kind) {
    ApiFailureKind.unknown || ApiFailureKind.parsing => 'Please try again.',
    _ => error.friendlyMessage,
  };
}
