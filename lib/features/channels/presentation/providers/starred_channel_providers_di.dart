import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

final starredChannelRepositoryProvider = Provider<StarredChannelRepository>(
  (ref) => StarredChannelRepositoryImpl(locator<SecureStorageService>()),
);

/// Null during session restoration or when signed out. No anonymous preferences.
final channelScopeProvider = Provider<({String userId, String workspaceId})?>((
  ref,
) {
  final auth = ref.watch(authNotifierProvider);
  final workspaceId = ref.watch(
    workspaceProvider.select((s) => s.selectedWorkspace?.id),
  );
  final userId = auth.user?.id;
  if (auth.status != AuthStatus.authenticated ||
      userId == null ||
      userId.isEmpty ||
      workspaceId == null ||
      workspaceId.isEmpty) {
    return null;
  }
  return (userId: userId, workspaceId: workspaceId);
});

final starredChannelProvider =
    NotifierProvider<StarredChannelNotifier, StarredChannelState>(
      StarredChannelNotifier.new,
    );

class StarredChannelState {
  const StarredChannelState({
    this.ids = const {},
    this.isLoading = false,
    this.isSaving = false,
    this.error,
    this.loaded = false,
  });
  final Set<String> ids;
  final bool isLoading;
  final bool isSaving;
  final bool loaded;
  final String? error;
}

class StarredChannelNotifier extends Notifier<StarredChannelState> {
  Object _generation = Object();

  @override
  StarredChannelState build() {
    final scope = ref.watch(channelScopeProvider);
    final generation = _generation = Object();
    ref.onDispose(() => _generation = Object());
    if (scope == null) return const StarredChannelState();
    Future.microtask(() => _load(scope, generation));
    return const StarredChannelState(isLoading: true);
  }

  Future<void> _load(
    ({String userId, String workspaceId}) scope,
    Object generation,
  ) async {
    if (!ref.mounted || generation != _generation) return;
    final result = await ref
        .read(starredChannelRepositoryProvider)
        .load(scope.userId, scope.workspaceId);
    if (!ref.mounted || generation != _generation) return;
    state = switch (result) {
      Success<Set<String>>(:final value) => StarredChannelState(
        ids: Set.unmodifiable(value),
        loaded: true,
      ),
      Failure<Set<String>>() => const StarredChannelState(
        error: 'Could not load starred channels. Try again.',
      ),
    };
  }

  void retry() => ref.invalidateSelf();

  Future<void> toggle(Channel channel) async {
    final scope = ref.read(channelScopeProvider);
    if (scope == null ||
        !state.loaded ||
        state.isSaving ||
        channel.organisationId != scope.workspaceId) {
      return;
    }
    if (channel.id.isEmpty) {
      state = StarredChannelState(
        ids: state.ids,
        loaded: true,
        error: 'This channel has no ID. Reload channels and try again.',
      );
      return;
    }
    final generation = _generation;
    final previous = state.ids;
    final next = {...previous};
    if (!next.remove(channel.id)) next.add(channel.id);
    state = StarredChannelState(
      ids: Set.unmodifiable(next),
      loaded: true,
      isSaving: true,
    );
    final result = await ref
        .read(starredChannelRepositoryProvider)
        .save(scope.userId, scope.workspaceId, next);
    if (!ref.mounted || generation != _generation) return;
    state = result is Success<void>
        ? StarredChannelState(ids: Set.unmodifiable(next), loaded: true)
        : StarredChannelState(
            ids: previous,
            loaded: true,
            error: 'Could not save starred channels. Try again.',
          );
  }
}

final workspaceChannelsProvider = Provider<List<Channel>>((ref) {
  final scope = ref.watch(channelScopeProvider);
  final channels = ref.watch(channelProvider.select((s) => s.channels));
  return channels.where((c) => c.organisationId == scope?.workspaceId).toList();
});

class SelectedChannelNotifier extends Notifier<String?> {
  @override
  String? build() {
    ref.watch(channelScopeProvider);
    return null;
  }

  void select(String id) {
    if (!ref
        .read(workspaceChannelsProvider)
        .any((c) => c.id == id && id.isNotEmpty)) {
      return;
    }
    state = id;
    ref.read(activeChatProvider.notifier).selectChannel(id);
  }
}

final selectedChannelIdProvider =
    NotifierProvider<SelectedChannelNotifier, String?>(
      SelectedChannelNotifier.new,
    );

final selectedChannelProvider = Provider<Channel?>((ref) {
  final channels = ref.watch(workspaceChannelsProvider);
  final id = ref.watch(selectedChannelIdProvider);
  for (final channel in channels) {
    if (channel.id == id) return channel;
  }
  return channels.isEmpty ? null : channels.first;
});
