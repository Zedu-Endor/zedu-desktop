import 'dart:convert';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class StarredChannelRepositoryImpl implements StarredChannelRepository {
  StarredChannelRepositoryImpl(this.storage);

  final SecureStorageService storage;

  String _key(String userId, String workspaceId) =>
      'starred_channels.v1.${base64Url.encode(utf8.encode(jsonEncode([userId, workspaceId])))}';

  @override
  Future<Result<Set<String>>> load(String userId, String workspaceId) async {
    try {
      final value = await storage.readData(_key(userId, workspaceId));
      return Success(
        value == null
            ? <String>{}
            : (jsonDecode(value) as List<dynamic>).cast<String>().toSet(),
      );
    } catch (error) {
      return Failure(ApiFailure.unknown(error));
    }
  }

  @override
  Future<Result<void>> save(
    String userId,
    String workspaceId,
    Set<String> channelIds,
  ) async {
    try {
      await storage.writeData(
        _key(userId, workspaceId),
        jsonEncode(channelIds.toList()),
      );
      return const Success(null);
    } catch (error) {
      return Failure(ApiFailure.unknown(error));
    }
  }
}
