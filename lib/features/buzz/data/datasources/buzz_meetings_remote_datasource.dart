import 'package:zedu/core/core.dart';

abstract class BuzzMeetingsRemoteDataSource {
  Future<String> createMeeting();
}

/// Creates meetings as the web Buzz page does.
class BuzzMeetingsRemoteDataSourceImpl implements BuzzMeetingsRemoteDataSource {
  final ApiBaseService apiBaseService;

  BuzzMeetingsRemoteDataSourceImpl({required this.apiBaseService});

  @override
  Future<String> createMeeting() async {
    final response = await apiBaseService.post<Map<String, dynamic>>(
      path: '/buzz/org/create',
      data: const <String, dynamic>{},
    );
    final data = response.data['data'];
    final code = data is Map ? data['buzz_code']?.toString().trim() ?? '' : '';
    if (code.isEmpty) {
      throw const ApiFailure(
        message: 'Failed to create meeting. Please try again.',
        path: '/buzz/org/create',
        kind: ApiFailureKind.parsing,
      );
    }
    return code;
  }
}
