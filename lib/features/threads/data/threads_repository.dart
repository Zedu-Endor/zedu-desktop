import 'package:zedu/core/core.dart';
import 'package:zedu/features/threads/threads.dart';

class ThreadsRepository {
  const ThreadsRepository(this.api);
  final ApiBaseService api;
  Future<ThreadsPage> load(String orgId, {int page = 1}) async {
    if (orgId.isEmpty || page < 1) {
      throw ArgumentError('Invalid thread request');
    }
    final response = await api.get<Map<String, dynamic>>(
      path: '/threads/organisations/${Uri.encodeComponent(orgId)}',
      queryParameters: {'page': page, 'limit': 50},
    );
    return ThreadsPage.fromJson(response.data, page);
  }
}

final threadsRepositoryProvider = Provider<ThreadsRepository>(
  (ref) => ThreadsRepository(locator<ApiBaseService>()),
);
