import 'package:zedu/core/core.dart';

abstract class StarredChannelRepository {
  Future<Result<Set<String>>> load(String userId, String workspaceId);
  Future<Result<void>> save(
    String userId,
    String workspaceId,
    Set<String> channelIds,
  );
}
