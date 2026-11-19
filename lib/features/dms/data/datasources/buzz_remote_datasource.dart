import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// HTTP calls to the Buzz endpoints. Request bodies and response fields match
/// the web app (`zedu-fe`) and the backend's request models.
abstract class BuzzRemoteDataSource {
  Future<DirectCall> startDirectCall(String channelId);
  Future<BuzzSession> join(String buzzIdOrCode);
  Future<DirectCall> respond(String buzzId, BuzzCallResponse action);
  Future<BuzzAgoraCredentials> token({
    required String buzzId,
    required String uid,
  });
  Future<void> leave(String buzzId);
  Future<void> end(String buzzId);
  Future<void> sendReaction(String buzzId, String emoji);
  Future<void> muteParticipants(String buzzId);
  Future<Map<String, dynamic>> metadata(String buzzId);
}

class BuzzRemoteDataSourceImpl implements BuzzRemoteDataSource {
  BuzzRemoteDataSourceImpl({required this.apiBaseService});

  final ApiBaseService apiBaseService;

  @override
  Future<DirectCall> startDirectCall(String channelId) async {
    final response = await apiBaseService.post<Map<String, dynamic>>(
      path: '/buzz/direct-call',
      data: {'channel_id': channelId},
    );
    final call = DirectCall.fromJson(_data(response, '/buzz/direct-call'));
    if (call.joinId.isEmpty) {
      throw ApiFailure.fromParsingError(
        'no buzz_code or buzz_id',
        path: '/buzz/direct-call',
      );
    }
    return call;
  }

  @override
  Future<BuzzSession> join(String buzzIdOrCode) async {
    final path = '/buzz/$buzzIdOrCode/join';
    final response = await apiBaseService.post<Map<String, dynamic>>(
      path: path,
    );
    final session = BuzzSession.fromJson(_data(response, path));
    if (!session.agora.isComplete || session.agora.appId.isEmpty) {
      throw ApiFailure.fromParsingError('incomplete agora_token', path: path);
    }
    return session;
  }

  @override
  Future<DirectCall> respond(String buzzId, BuzzCallResponse action) async {
    final path = '/buzz/$buzzId/respond';
    final response = await apiBaseService.post<Map<String, dynamic>>(
      path: path,
      data: {'action': action.apiValue},
    );
    return DirectCall.fromJson(_data(response, path));
  }

  @override
  Future<BuzzAgoraCredentials> token({
    required String buzzId,
    required String uid,
  }) async {
    final response = await apiBaseService.post<Map<String, dynamic>>(
      path: '/buzz/token',
      data: {'buzz_id': buzzId, 'uid': uid},
    );
    final credentials = BuzzAgoraCredentials.fromJson(
      _data(response, '/buzz/token'),
    );
    if (!credentials.isComplete) {
      throw ApiFailure.fromParsingError(
        'missing token or uid',
        path: '/buzz/token',
      );
    }
    return credentials;
  }

  @override
  Future<void> leave(String buzzId) async {
    await apiBaseService.post<Map<String, dynamic>>(
      path: '/buzz/$buzzId/leave',
    );
  }

  @override
  Future<void> end(String buzzId) async {
    await apiBaseService.post<Map<String, dynamic>>(
      path: '/buzz/$buzzId/end',
      data: const <String, dynamic>{},
    );
  }

  @override
  Future<void> sendReaction(String buzzId, String emoji) async {
    await apiBaseService.post<Map<String, dynamic>>(
      path: '/buzz/$buzzId/reaction',
      data: {'reaction_type': 'emoji', 'content': emoji},
    );
  }

  @override
  Future<void> muteParticipants(String buzzId) async {
    await apiBaseService.post<Map<String, dynamic>>(
      path: '/buzz/$buzzId/mute-participants',
      data: const <String, dynamic>{},
    );
  }

  @override
  Future<Map<String, dynamic>> metadata(String buzzId) async {
    final path = '/buzz/$buzzId/metadata';
    final response = await apiBaseService.get<Map<String, dynamic>>(path: path);
    return _data(response, path);
  }

  /// The `data` object of a `{ data: … }` response.
  Map<String, dynamic> _data(
    ApiResponseModel<Map<String, dynamic>> response,
    String path,
  ) {
    final data = response.data['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    throw ApiFailure.fromParsingError('no data object', path: path);
  }
}
