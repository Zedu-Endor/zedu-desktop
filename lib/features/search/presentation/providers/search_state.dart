import 'package:zedu/features/features.dart';

enum SearchStatus { initial, loading, ready, error }

class SearchState {
  const SearchState({
    this.status = SearchStatus.initial,
    this.query = '',
    this.results = const [],
    this.error,
  });

  final SearchStatus status;
  final String query;
  final List<SearchResult> results;
  final String? error;

  bool get isLoading => status == SearchStatus.loading;

  bool get hasQuery => query.trim().isNotEmpty;

  SearchState copyWith({
    SearchStatus? status,
    String? query,
    List<SearchResult>? results,
    String? error,
    bool clearError = false,
  }) {
    return SearchState(
      status: status ?? this.status,
      query: query ?? this.query,
      results: results ?? this.results,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
