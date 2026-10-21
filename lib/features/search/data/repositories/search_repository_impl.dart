import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class SearchRepositoryImpl implements SearchRepository {
  const SearchRepositoryImpl({required SearchRemoteDataSource remote})
    : _remote = remote;

  final SearchRemoteDataSource _remote;

  @override
  Future<Result<List<SearchResult>>> searchOrganisationMessages({
    required String orgId,
    required String query,
    String sortBy = 'relevance',
  }) async {
    if (orgId.trim().isEmpty || query.trim().isEmpty) {
      return const Success([]);
    }

    try {
      final models = await _remote.searchOrganisationMessages(
        orgId: orgId,
        query: query,
        sortBy: sortBy,
      );

      return Success(
        models
            .map(
              (model) => SearchResult(
                user: SearchUser(
                  userId: model.user.userId,
                  userName: model.user.userName,
                  avatarUrl: model.user.avatarUrl,
                  defaultAvatarUrl: model.user.defaultAvatarUrl,
                  isDeactivated: model.user.isDeactivated,
                ),
                messages: model.messages
                    .map(
                      (message) => SearchMessage(
                        messageId: message.messageId,
                        threadId: message.threadId,
                        text: message.text,
                        timestamp: message.timestamp,
                      ),
                    )
                    .toList(),
                channel: SearchChannel(
                  channelId: model.channel.channelId,
                  channelName: model.channel.channelName,
                  channelType: model.channel.channelType,
                ),
              ),
            )
            .toList(),
      );
    } on ApiFailure catch (failure) {
      return Failure(failure);
    } catch (error) {
      return Failure(ApiFailure.unknown(error));
    }
  }
}
