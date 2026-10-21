import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Reads search results from the Zedu backend.
abstract interface class SearchRemoteDataSource {
  /// Searches messages across the organisation.
  ///
  /// [query] is the raw user input; [sortBy] is one of `relevance`,
  /// `newest` or `oldest`.
  Future<List<SearchResultModel>> searchOrganisationMessages({
    required String orgId,
    required String query,
    String sortBy = 'relevance',
  });
}

class SearchRemoteDataSourceImpl implements SearchRemoteDataSource {
  const SearchRemoteDataSourceImpl({required ApiBaseService apiBaseService})
    : _api = apiBaseService;

  final ApiBaseService _api;

  @override
  Future<List<SearchResultModel>> searchOrganisationMessages({
    required String orgId,
    required String query,
    String sortBy = 'relevance',
  }) async {
    final trimmedQuery = query.trim();
    if (orgId.isEmpty || trimmedQuery.isEmpty) {
      return const [];
    }

    final response = await _api.get<Map<String, dynamic>>(
      path: '/search/organisation/$orgId',
      queryParameters: {'query': trimmedQuery, 'sortBy': sortBy},
    );

    final data = response.data['data'];
    if (data is! List) {
      return const [];
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(SearchResultModel.fromJson)
        .toList();
  }
}
