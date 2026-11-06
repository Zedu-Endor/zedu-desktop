import '../../../../helpers/helpers.dart';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockApiBaseService extends Mock implements ApiBaseService {}

void main() {
  group('UserProfileRemoteDataSourceImpl.getTeamMembers org (Ziki #1452)', () {
    late MockApiBaseService api;
    late UserProfileRemoteDataSourceImpl dataSource;

    setUp(() {
      api = MockApiBaseService();
      dataSource = UserProfileRemoteDataSourceImpl(
        config: const AppConfig(
          apiBaseUrl: 'https://api.example.com',
          usesMockData: false,
        ),
        apiBaseService: api,
      );
      when(
        () => api.get<Map<String, dynamic>>(path: any(named: 'path')),
      ).thenAnswer(
        (_) async => const ApiResponseModel(
          data: <String, dynamic>{'data': <dynamic>[]},
          statusCode: 200,
        ),
      );
    });

    test('with no workspace selected it asks for no one', () async {
      final members = await dataSource.getTeamMembers();

      expect(members, isEmpty);
      verifyNever(
        () => api.get<Map<String, dynamic>>(path: any(named: 'path')),
      );
    });

    test('never swaps in another organisation for the one given', () async {
      await dataSource.getTeamMembers(orgId: 'org-1');

      verify(
        () => api.get<Map<String, dynamic>>(path: '/organisations/org-1/users'),
      ).called(1);
      verifyNever(
        () => api.get<Map<String, dynamic>>(
          path: '/organisations/019700db-4e22-7f90-a20e-f9116291ef24/users',
        ),
      );
    });
  });
}
