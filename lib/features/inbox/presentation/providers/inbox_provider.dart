import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Whether the inbox is filtered to unread rows only.
class InboxUnreadFilterNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final inboxUnreadFilterProvider =
    NotifierProvider<InboxUnreadFilterNotifier, bool>(
      InboxUnreadFilterNotifier.new,
    );

/// The merged inbox across every workspace the user belongs to.
///
/// It watches the workspace list rather than the selected workspace, so
/// switching workspaces does not refetch and does not change what is shown.
class InboxNotifier extends AsyncNotifier<InboxSnapshot> {
  @override
  Future<InboxSnapshot> build() async {
    final workspaces = ref.watch(
      workspaceProvider.select((state) => state.workspaces),
    );
    if (workspaces.isEmpty) return const InboxSnapshot();
    return ref.read(inboxRepositoryProvider).load(workspaces);
  }

  /// Re-reads every workspace. Used by the refresh action.
  Future<void> refresh() async {
    final workspaces = ref.read(workspaceProvider).workspaces;
    if (workspaces.isEmpty) {
      state = const AsyncValue.data(InboxSnapshot());
      return;
    }
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(inboxRepositoryProvider).load(workspaces),
    );
  }
}

final inboxProvider = AsyncNotifierProvider<InboxNotifier, InboxSnapshot>(
  InboxNotifier.new,
);

/// Unread total across every workspace, for the rail badge.
///
/// This reads the counts the workspace list already carries rather than the
/// inbox itself. The badge is on screen from startup, and watching
/// [inboxProvider] would fan out a request per workspace before the user has
/// asked for the inbox at all. The dialog does the real fetch when opened.
final inboxUnreadCountProvider = Provider<int>((ref) {
  final workspaces = ref.watch(
    workspaceProvider.select((state) => state.workspaces),
  );
  return workspaces.fold(0, (sum, workspace) => sum + workspace.unreadCount);
});
