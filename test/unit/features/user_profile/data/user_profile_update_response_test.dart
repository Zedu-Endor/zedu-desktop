import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../helpers/helpers.dart';

class _Api extends Mock implements ApiBaseService {}

void main() {
  const config = AppConfig(
    apiBaseUrl: 'https://api.example.test/api/v1/',
    usesMockData: false,
  );

  group('profile update responses', () {
    test('account update accepts an empty successful response', () async {
      final api = _Api();
      when(
        () => api.patch<dynamic>(
          path: '/profile/account',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async =>
            const ApiResponseModel<dynamic>(data: null, statusCode: 204),
      );

      const account = ProfileAccount(
        name: 'Ada Lovelace',
        email: 'ada@example.test',
        timezone: 'Africa/Lagos',
      );
      final result = await UserProfileRemoteDataSourceImpl(
        config: config,
        apiBaseService: api,
      ).updateAccount(account);

      expect(result.name, account.name);
      expect(result.email, account.email);
      expect(result.timezone, account.timezone);
    });

    test('organization update accepts an acknowledgement response', () async {
      final api = _Api();
      when(
        () => api.patch<dynamic>(
          path: '/profile/organization',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => const ApiResponseModel<dynamic>(
          data: {'message': 'Organization updated'},
          statusCode: 200,
        ),
      );

      const organization = OrganizationProfile(
        id: 'org-123',
        name: 'Analytical Engines',
        natureOfBusiness: 'Research',
        country: 'United Kingdom',
      );
      final result = await UserProfileRemoteDataSourceImpl(
        config: config,
        apiBaseService: api,
      ).updateOrganization(organization);

      expect(result.id, organization.id);
      expect(result.name, organization.name);
      expect(result.natureOfBusiness, organization.natureOfBusiness);
      expect(result.country, organization.country);
    });

    test('server fields override submitted values when returned', () async {
      final api = _Api();
      when(
        () => api.patch<dynamic>(
          path: '/profile/account',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => const ApiResponseModel<dynamic>(
          data: {
            'data': {
              'name': 'Ada Byron',
              'email': 'ada.byron@example.test',
              'timezone': 'Europe/London',
            },
          },
          statusCode: 200,
        ),
      );

      final result =
          await UserProfileRemoteDataSourceImpl(
            config: config,
            apiBaseService: api,
          ).updateAccount(
            const ProfileAccount(
              name: 'Ada Lovelace',
              email: 'ada@example.test',
              timezone: 'Africa/Lagos',
            ),
          );

      expect(result.name, 'Ada Byron');
      expect(result.email, 'ada.byron@example.test');
      expect(result.timezone, 'Europe/London');
    });
  });
}
