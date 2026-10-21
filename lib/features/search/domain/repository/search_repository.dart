import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

abstract interface class SearchRepository {
  /// Searches messages across the organisation.
  ///
  /// An empty [query] or [orgId] resolves to an empty list without a request.
  Future<Result<List<SearchResult>>> searchOrganisationMessages({
    required String orgId,
    required String query,
    String sortBy = 'relevance',
  });
}
