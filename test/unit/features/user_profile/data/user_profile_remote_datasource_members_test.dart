import '../../../../helpers/helpers.dart';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockApiBaseService extends Mock implements ApiBaseService {}

const _orgId = '019700db-4e22-7f90-a20e-f9116291ef00';

// Shaped like GET /organisations/{orgId}/users (zedu-be UserInOrgResponse).
ApiResponseModel<Map<String, dynamic>> _users() {
  return const ApiResponseModel(
    data: <String, dynamic>{
      'data': [
        {
          'id': 'u1',
          'email': 'ada@zedu.chat',
          'name': 'Ada',
          'role': 'Admin',
          'status': 'active',
          'is_deactivated': false,
          'created_at': '2026-11-01T10:00:00Z',
        },
        {
          'id': 'u2',
          'email': 'grace@zedu.chat',
          'name': 'Grace',
          'role': 'User',
          'status': 'Pending',
          'is_deactivated': false,
          'created_at': '2026-11-02T10:00:00Z',
        },
        {
          'id': 'u3',
          'email': 'old@zedu.chat',
          'name': 'Old',
          'role': 'User',
          'status': 'active',
          'is_deactivated': true,
          'created_at': '2026-10-02T10:00:00Z',
        },
        {
          'id': 'u4',
          'email': 'nostatus@zedu.chat',
          'name': 'No status',
          'role': 'User',
          'created_at': '2026-10-03T10:00:00Z',
        },
      ],
    },
    statusCode: 200,
  );
}

void main() {
  group(
    'UserProfileRemoteDataSourceImpl.getTeamMembers status (Ziki #2868)',
    () {
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
        ).thenAnswer((_) async => _users());
      });

      test(
        'reads each member\'s status instead of marking all active',
        () async {
          final members = await dataSource.getTeamMembers(orgId: _orgId);

          expect(
            {for (final m in members) m.id: m.status},
            {
              'u1': TeamMemberStatus.active,
              'u2': TeamMemberStatus.pending,
              'u3': TeamMemberStatus.inactive,
              'u4': TeamMemberStatus.active,
            },
          );
        },
      );
    },
  );

  group('TeamMemberModel.statusFromJson', () {
    test('maps pending and inactive in any case', () {
      expect(
        TeamMemberModel.statusFromJson(const {'status': 'PENDING'}),
        TeamMemberStatus.pending,
      );
      expect(
        TeamMemberModel.statusFromJson(const {'status': 'inactive'}),
        TeamMemberStatus.inactive,
      );
      expect(
        TeamMemberModel.statusFromJson(const {'status': 'active'}),
        TeamMemberStatus.active,
      );
    });

    test('a deactivated account is inactive whatever its status says', () {
      expect(
        TeamMemberModel.statusFromJson(const {
          'status': 'active',
          'is_deactivated': true,
        }),
        TeamMemberStatus.inactive,
      );
    });
  });
}
