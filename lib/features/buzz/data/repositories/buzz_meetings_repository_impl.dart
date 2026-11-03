import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class BuzzMeetingsRepositoryImpl implements BuzzMeetingsRepository {
  final BuzzMeetingsRemoteDataSource remoteDataSource;

  BuzzMeetingsRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Result<String>> createMeeting() async {
    try {
      return Success(await remoteDataSource.createMeeting());
    } on ApiFailure catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(ApiFailure(message: e.toString()));
    }
  }
}
