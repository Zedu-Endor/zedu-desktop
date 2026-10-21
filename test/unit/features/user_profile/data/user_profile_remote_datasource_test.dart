import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../helpers/helpers.dart';

class _Api extends Mock implements ApiBaseService {}

void main() {
  const config = AppConfig(
    apiBaseUrl: 'https://api.example.test',
    usesMockData: false,
  );

  test(
    'deleteAccount deactivates the signed-in user at DELETE /users/me',
    () async {
      final api = _Api();
      when(
        () => api.delete<Map<String, dynamic>>(path: any(named: 'path')),
      ).thenAnswer(
        (_) async => ApiResponseModel<Map<String, dynamic>>(
          data: const {},
          statusCode: 200,
        ),
      );

      await UserProfileRemoteDataSourceImpl(
        config: config,
        apiBaseService: api,
      ).deleteAccount();

      verify(
        () => api.delete<Map<String, dynamic>>(path: '/users/me'),
      ).called(1);
      verifyNever(
        () => api.delete<Map<String, dynamic>>(path: '/profile/account'),
      );
    },
  );
}
