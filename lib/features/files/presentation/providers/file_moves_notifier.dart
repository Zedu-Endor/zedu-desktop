import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Ids of the files being moved.
class FileMovesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  /// Moves [file] into [folder], then reloads the files and folders, since
  /// the file leaves this list and the folder's item count changes. Returns
  /// what to tell the person when it failed, or null.
  Future<String?> move(WorkspaceFile file, FileFolder folder) async {
    if (state.contains(file.id)) return null;

    state = {...state, file.id};
    final result = await ref
        .read(filesRepositoryProvider)
        .moveFile(file.id, folder.id);
    if (!ref.mounted) return null;
    state = {...state}..remove(file.id);

    switch (result) {
      case Success():
        ref
          ..invalidate(filesListProvider)
          ..invalidate(foldersListProvider);
        return null;
      case Failure(:final error):
        return 'Could not move ${file.name}. ${_reason(error)}';
    }
  }

  static String _reason(ApiFailure error) => switch (error.kind) {
    ApiFailureKind.unknown || ApiFailureKind.parsing => 'Please try again.',
    _ => error.friendlyMessage,
  };
}
