import '../../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class _MockRepo extends Mock implements UserProfileRepository {}

class _MockStorage extends Mock implements SecureStorageService {}

class _Workspace extends WorkspaceNotifier {
  @override
  WorkspaceState build() => const WorkspaceState(
    selectedWorkspace: Workspace(
      id: '019700db-4e22-7f90-a20e-f9116291ef24',
      name: 'Team',
      avatar: '',
    ),
  );
}

/// Answers every request; records the POST /invite/general one.
Dio _dio(void Function(RequestOptions) onInvite) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path.endsWith('invite/general')) onInvite(options);
        handler.resolve(
          Response<Map<String, dynamic>>(
            requestOptions: options,
            data: {
              'data': {
                'invitation_link':
                    'https://example.com/accept_general_invitation?x=1',
              },
            },
          ),
        );
      },
    ),
  );
  return dio;
}

void main() {
  group('UserProfileNotifier.generateInviteLink Referer (Ziki #2708)', () {
    late _MockRepo repo;

    setUp(() {
      repo = _MockRepo();
      final storage = _MockStorage();
      when(() => storage.readData(any())).thenAnswer((_) async => null);
      locator.registerSingleton<SecureStorageService>(storage);
      Future<Result<T>> failed<T>() async =>
          Failure<T>(const ApiFailure(message: 'unavailable'));
      when(() => repo.getAccount()).thenAnswer((_) => failed());
      when(
        () => repo.getNotificationPreferences(orgId: any(named: 'orgId')),
      ).thenAnswer((_) => failed());
      when(
        () => repo.getSecuritySessions(userId: any(named: 'userId')),
      ).thenAnswer((_) => failed());
      when(
        () => repo.getOrganization(orgId: any(named: 'orgId')),
      ).thenAnswer((_) => failed());
      when(
        () => repo.getTeamMembers(orgId: any(named: 'orgId')),
      ).thenAnswer((_) => failed());
      when(() => repo.getRolesAndPermissions()).thenAnswer((_) => failed());
      when(() => repo.getBillingInfo()).thenAnswer((_) => failed());
    });

    tearDown(() async => locator.reset());

    Future<RequestOptions?> generate({String webAppUrl = ''}) async {
      final config = AppConfig(
        apiBaseUrl: 'https://api.example.com/api/v1/',
        usesMockData: false,
        webAppUrl: webAppUrl,
      );
      RequestOptions? invite;
      locator
        ..registerSingleton<AppConfig>(config)
        ..registerSingleton<ApiBaseService>(
          ApiBaseService(config: config, dio: _dio((o) => invite = o)),
        );
      final container = ProviderContainer(
        overrides: [
          userProfileRepositoryProvider.overrideWithValue(repo),
          workspaceProvider.overrideWith(_Workspace.new),
        ],
      );
      addTearDown(container.dispose);
      container.listen(userProfileNotifierProvider, (_, _) {});

      final link = await container
          .read(userProfileNotifierProvider.notifier)
          .generateInviteLink();
      expect(link, isNotNull);
      return invite;
    }

    test('sends the web app address so the link has a host', () async {
      final invite = await generate();

      expect(invite, isNotNull);
      expect(invite!.headers['Referer'], 'https://example.com/');
    });

    test('uses WEB_APP_URL when it is set', () async {
      final invite = await generate(webAppUrl: 'https://app.zedu.chat/');

      expect(invite!.headers['Referer'], 'https://app.zedu.chat/');
    });
  });
}
