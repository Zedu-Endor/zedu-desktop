import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

final buzzRemoteDataSourceProvider = Provider<BuzzRemoteDataSource>(
  (ref) => BuzzRemoteDataSourceImpl(apiBaseService: locator<ApiBaseService>()),
);

final buzzRepositoryProvider = Provider<BuzzCallRepository>(
  (ref) => BuzzCallRepositoryImpl(
    remoteDataSource: ref.watch(buzzRemoteDataSourceProvider),
  ),
);

class BuzzCallRepositoryImpl implements BuzzCallRepository {
  BuzzCallRepositoryImpl({required this.remoteDataSource});

  final BuzzRemoteDataSource remoteDataSource;

  @override
  Future<Result<DirectCall>> startDirectCall(String channelId) =>
      _guard(() => remoteDataSource.startDirectCall(channelId));

  @override
  Future<Result<BuzzSession>> join(String buzzIdOrCode) =>
      _guard(() => remoteDataSource.join(buzzIdOrCode));

  @override
  Future<Result<DirectCall>> respond(String buzzId, BuzzCallResponse action) =>
      _guard(() => remoteDataSource.respond(buzzId, action));

  @override
  Future<Result<BuzzAgoraCredentials>> token({
    required String buzzId,
    required String uid,
  }) => _guard(() => remoteDataSource.token(buzzId: buzzId, uid: uid));

  @override
  Future<Result<void>> leave(String buzzId) =>
      _guard(() => remoteDataSource.leave(buzzId));

  @override
  Future<Result<void>> end(String buzzId) =>
      _guard(() => remoteDataSource.end(buzzId));

  @override
  Future<Result<void>> sendReaction(String buzzId, String emoji) =>
      _guard(() => remoteDataSource.sendReaction(buzzId, emoji));

  @override
  Future<Result<void>> muteParticipants(String buzzId) =>
      _guard(() => remoteDataSource.muteParticipants(buzzId));

  @override
  Future<Result<Map<String, dynamic>>> metadata(String buzzId) =>
      _guard(() => remoteDataSource.metadata(buzzId));

  Future<Result<T>> _guard<T>(Future<T> Function() call) async {
    try {
      return Success(await call());
    } on ApiFailure catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(ApiFailure(message: e.toString()));
    }
  }
}
