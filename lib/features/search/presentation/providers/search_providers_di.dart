import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

final searchRemoteDataSourceProvider = Provider<SearchRemoteDataSource>(
  (ref) => SearchRemoteDataSourceImpl(
    apiBaseService: locator<ApiBaseService>(),
  ),
);

final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => SearchRepositoryImpl(remote: ref.watch(searchRemoteDataSourceProvider)),
);

final searchNotifierProvider =
    NotifierProvider<SearchNotifier, SearchState>(SearchNotifier.new);
