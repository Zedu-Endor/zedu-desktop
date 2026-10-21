import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class SearchNotifier extends Notifier<SearchState> {
  late final SearchRepository _repository;

  @override
  SearchState build() {
    _repository = ref.read(searchRepositoryProvider);
    return const SearchState();
  }

  /// Runs a search for [query] in [orgId].
  ///
  /// An empty query clears the results without hitting the network.
  Future<void> search({
    required String orgId,
    required String query,
  }) async {
    final trimmed = query.trim();

    if (trimmed.isEmpty) {
      state = state.copyWith(
        status: SearchStatus.initial,
        query: '',
        results: const [],
        clearError: true,
      );
      return;
    }

    state = state.copyWith(
      status: SearchStatus.loading,
      query: trimmed,
      clearError: true,
    );

    final result = await _repository.searchOrganisationMessages(
      orgId: orgId,
      query: trimmed,
    );

    switch (result) {
      case Success<List<SearchResult>>():
        state = state.copyWith(
          status: SearchStatus.ready,
          results: result.value,
          clearError: true,
        );
      case Failure<List<SearchResult>>():
        state = state.copyWith(
          status: SearchStatus.error,
          results: const [],
          error: result.error.friendlyMessage,
        );
    }
  }

  void clear() {
    state = const SearchState();
  }
}
