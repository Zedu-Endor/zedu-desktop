import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Ids of the files being renamed.
class FileRenamesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  /// Renames [file] to [name] and reloads the list when it worked. Returns
  /// what to tell the person when it failed, or null.
  Future<String?> rename(WorkspaceFile file, String name) async {
    final newName = name.trim();
    if (newName.isEmpty) return 'Enter a file name.';
    if (newName == file.name || state.contains(file.id)) return null;

    state = {...state, file.id};
    final result = await ref
        .read(filesRepositoryProvider)
        .renameFile(file.id, newName);
    if (!ref.mounted) return null;
    state = {...state}..remove(file.id);

    switch (result) {
      case Success():
        ref.invalidate(filesListProvider);
        return null;
      case Failure(:final error):
        return 'Could not rename ${file.name}. ${_reason(error)}';
    }
  }

  static String _reason(ApiFailure error) => switch (error.kind) {
    ApiFailureKind.unknown || ApiFailureKind.parsing => 'Please try again.',
    _ => error.friendlyMessage,
  };
}
