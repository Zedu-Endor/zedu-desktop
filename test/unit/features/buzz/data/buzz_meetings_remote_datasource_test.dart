import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../helpers/helpers.dart';

class MockApiBaseService extends Mock implements ApiBaseService {}

void main() {
  late MockApiBaseService api;
  late BuzzMeetingsRemoteDataSourceImpl datasource;

  setUp(() {
    api = MockApiBaseService();
    datasource = BuzzMeetingsRemoteDataSourceImpl(apiBaseService: api);
  });

  void answer(Map<String, dynamic> body) {
    when(
      () => api.post<Map<String, dynamic>>(
        path: '/buzz/org/create',
        data: const <String, dynamic>{},
      ),
    ).thenAnswer(
      (_) async =>
          ApiResponseModel<Map<String, dynamic>>(statusCode: 201, data: body),
    );
  }

  test('creates a meeting and returns its code', () async {
    answer({
      'data': {'buzz_code': 'abc-defg-hij'},
    });

    expect(await datasource.createMeeting(), 'abc-defg-hij');
  });

  test('throws when the response has no code', () async {
    answer({'data': <String, dynamic>{}});

    expect(datasource.createMeeting, throwsA(isA<ApiFailure>()));
  });
}
