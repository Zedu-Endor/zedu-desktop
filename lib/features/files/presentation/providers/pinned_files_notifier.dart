import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Ids of the files the user pinned in the current workspace. The server keeps
/// them, so they stay pinned across visits and devices.
class PinnedFilesNotifier extends AsyncNotifier<Set<String>> {
  final _pending = <String>{};

  @override
  Future<Set<String>> build() async {
    ref.watch(currentOrgIdProvider);
    final result = await ref.read(filesRepositoryProvider).fetchPinnedFileIds();
    // Without the pins the files still list, just unmarked, as on web.
    return switch (result) {
      Success(:final value) => value,
      Failure() => const {},
    };
  }

  bool isPinned(String fileId) => state.value?.contains(fileId) ?? false;

  /// Pins [file], or unpins it when pinned. The list changes at once and
  /// changes back if the server refuses. Returns what to tell the person when
  /// it failed, or null.
  Future<String?> toggle(WorkspaceFile file) async {
    if (!_pending.add(file.id)) return null;
    final wasPinned = isPinned(file.id);
    _set(file.id, pinned: !wasPinned);

    final repository = ref.read(filesRepositoryProvider);
    final result = wasPinned
        ? await repository.unpinFile(file.id)
        : await repository.pinFile(file.id);
    _pending.remove(file.id);
    if (!ref.mounted) return null;

    switch (result) {
      case Success():
        return null;
      case Failure(:final error):
        _set(file.id, pinned: wasPinned);
        return 'Could not ${wasPinned ? 'unpin' : 'pin'} ${file.name}. '
            '${_reason(error)}';
    }
  }

  void _set(String fileId, {required bool pinned}) {
    final ids = {...?state.value};
    pinned ? ids.add(fileId) : ids.remove(fileId);
    state = AsyncData(ids);
  }

  static String _reason(ApiFailure error) => switch (error.kind) {
    ApiFailureKind.unknown || ApiFailureKind.parsing => 'Please try again.',
    _ => error.friendlyMessage,
  };
}
