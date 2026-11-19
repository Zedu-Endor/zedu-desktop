import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class ThreadsInboxState {
  const ThreadsInboxState({
    this.threads = const [],
    this.loading = false,
    this.loadingMore = false,
    this.hasMore = false,
    this.unseenCount = 0,
    this.error,
  });
  final List<InboxThread> threads;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final int unseenCount;
  final String? error;
}

class ThreadsInboxNotifier extends Notifier<ThreadsInboxState> {
  int _generation = 0;
  int _page = 0;
  String _orgId = '';
  @override
  ThreadsInboxState build() {
    final auth = ref.watch(authNotifierProvider);
    final selectedOrg = ref.watch(currentOrgIdProvider);
    _orgId = auth.status == AuthStatus.authenticated && auth.user != null
        ? selectedOrg
        : '';
    final orgId = _orgId;
    final generation = ++_generation;
    _page = 0;
    if (_orgId.isNotEmpty) {
      Future.microtask(() => _load(generation, orgId, append: false));
    }
    return ThreadsInboxState(loading: _orgId.isNotEmpty);
  }

  Future<void> refresh() async {
    if (_orgId.isEmpty) return;
    final generation = ++_generation;
    _page = 0;
    state = const ThreadsInboxState(loading: true);
    await _load(generation, _orgId, append: false);
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    state = ThreadsInboxState(
      threads: state.threads,
      loadingMore: true,
      hasMore: state.hasMore,
      unseenCount: state.unseenCount,
    );
    await _load(_generation, _orgId, append: true);
  }

  Future<void> _load(
    int generation,
    String orgId, {
    required bool append,
  }) async {
    // Capture the workspace before scheduling a request, never read a later one.
    if (!ref.mounted || generation != _generation || orgId != _orgId) return;
    try {
      final page = await ref
          .read(threadsRepositoryProvider)
          .load(orgId, page: append ? _page + 1 : 1);
      if (!ref.mounted || generation != _generation || orgId != _orgId) return;
      _page = append ? _page + 1 : 1;
      final merged = <String, InboxThread>{
        for (final thread in append ? state.threads : <InboxThread>[])
          thread.id: thread,
      };
      for (final thread in page.threads) {
        merged[thread.id] = thread;
      }
      state = ThreadsInboxState(
        threads: List.unmodifiable(merged.values),
        hasMore: page.hasMore,
        unseenCount: page.unseenCount,
      );
    } catch (_) {
      if (!ref.mounted || generation != _generation || orgId != _orgId) return;
      state = ThreadsInboxState(
        threads: append ? state.threads : const [],
        hasMore: append && state.hasMore,
        unseenCount: append ? state.unseenCount : 0,
        error: 'Could not load threads. Please try again.',
      );
    }
  }
}

final threadsInboxProvider =
    NotifierProvider<ThreadsInboxNotifier, ThreadsInboxState>(
      ThreadsInboxNotifier.new,
    );
