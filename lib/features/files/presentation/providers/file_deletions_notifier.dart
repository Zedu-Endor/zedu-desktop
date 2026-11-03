import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Ids of the files being deleted.
class FileDeletionsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  /// Deletes [file]: moves it to Deleted files, or removes it for good when
  /// [permanent]. Reloads the list when it worked. Returns what to tell the
  /// person when it failed, or null.
  Future<String?> delete(WorkspaceFile file, {bool permanent = false}) async {
    if (state.contains(file.id)) return null;
    state = {...state, file.id};
    final result = await ref
        .read(filesRepositoryProvider)
        .deleteFile(file.id, permanent: permanent);
    if (!ref.mounted) return null;
    state = {...state}..remove(file.id);

    switch (result) {
      case Success():
        ref.invalidate(filesListProvider);
        return null;
      case Failure(:final error):
        return 'Could not delete ${file.name}. ${_reason(error)}';
    }
  }

  static String _reason(ApiFailure error) => switch (error.kind) {
    ApiFailureKind.unknown || ApiFailureKind.parsing => 'Please try again.',
    _ => error.friendlyMessage,
  };
}
