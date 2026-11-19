import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class MockApiBaseService extends Mock implements ApiBaseService {}

void main() {
  late MockApiBaseService api;
  late CreditsRemoteDataSourceImpl datasource;

  CreditsRemoteDataSourceImpl createDatasource() => CreditsRemoteDataSourceImpl(
    config: const AppConfig(
      apiBaseUrl: 'https://example.invalid',
      usesMockData: true,
    ),
    apiBaseService: api,
  );

  setUp(() {
    api = MockApiBaseService();
    datasource = createDatasource();
  });

  test(
    'mock verification updates readable usage without an API request',
    () async {
      await datasource.verifyPayment(sessionId: 'mock-session');

      final usage = await datasource.getUsage('org');
      expect(usage.balance, 1010);
      expect(usage.totalPurchased, 1010);
      expect(usage.totalConsumed, 0);
      verifyZeroInteractions(api);
    },
  );

  test('subsequent mock verifications update existing usage', () async {
    await datasource.verifyPayment(sessionId: 'first-session');
    await datasource.verifyPayment(sessionId: 'second-session');

    final usage = await datasource.getUsage('org');
    expect(usage.balance, 2010);
    expect(usage.totalPurchased, 2010);
    expect(usage.totalConsumed, 0);
  });

  test('mock usage is isolated between datasource instances', () async {
    final other = createDatasource();
    await datasource.verifyPayment(sessionId: 'mock-session');

    final usage = await other.getUsage('org');
    expect(usage.balance, 10);
    expect(usage.totalPurchased, 10);
    expect(usage.totalConsumed, 0);
  });

  test(
    'live verification sends the session to the existing endpoint',
    () async {
      final live = CreditsRemoteDataSourceImpl(
        config: const AppConfig(
          apiBaseUrl: 'https://example.invalid',
          usesMockData: false,
        ),
        apiBaseService: api,
      );
      when(
        () => api.post<Map<String, dynamic>>(
          path: '/credits/verify-payment',
          data: {'session_id': 'live-session'},
        ),
      ).thenAnswer(
        (_) async =>
            const ApiResponseModel(data: <String, dynamic>{}, statusCode: 200),
      );

      await live.verifyPayment(sessionId: 'live-session');

      verify(
        () => api.post<Map<String, dynamic>>(
          path: '/credits/verify-payment',
          data: {'session_id': 'live-session'},
        ),
      ).called(1);
      verifyNoMoreInteractions(api);
    },
  );

  test(
    'live getUsage reads the balance from the usage-report endpoint',
    () async {
      final live = CreditsRemoteDataSourceImpl(
        config: const AppConfig(
          apiBaseUrl: 'https://example.invalid',
          usesMockData: false,
        ),
        apiBaseService: api,
      );
      // The report endpoint answers with the balance and the credited/used
      // aliases (see ZE-2700), and the usage model must pick them up.
      when(
        () =>
            api.get<Map<String, dynamic>>(path: '/credits/usage-report/org-1'),
      ).thenAnswer(
        (_) async => const ApiResponseModel(
          data: <String, dynamic>{
            'data': <String, dynamic>{
              'balance': 120,
              'total_credited': 500,
              'total_used': 380,
            },
          },
          statusCode: 200,
        ),
      );

      final usage = await live.getUsage('org-1');

      expect(usage.balance, 120);
      expect(usage.totalPurchased, 500);
      expect(usage.totalConsumed, 380);
      verify(
        () =>
            api.get<Map<String, dynamic>>(path: '/credits/usage-report/org-1'),
      ).called(1);
      verifyNoMoreInteractions(api);
    },
  );

  test(
    'live getUsage fails loudly when the report body is not a Map',
    () async {
      final live = CreditsRemoteDataSourceImpl(
        config: const AppConfig(
          apiBaseUrl: 'https://example.invalid',
          usesMockData: false,
        ),
        apiBaseService: api,
      );
      when(
        () =>
            api.get<Map<String, dynamic>>(path: '/credits/usage-report/org-1'),
      ).thenAnswer(
        (_) async => const ApiResponseModel(
          data: <String, dynamic>{
            'data': <Map<String, dynamic>>[
              {'amount': 5, 'agent_name': 'Ada'},
            ],
          },
          statusCode: 200,
        ),
      );

      await expectLater(live.getUsage('org-1'), throwsA(isA<ApiFailure>()));
    },
  );

  test(
    'live getUsageReport maps the report endpoint aliases to its totals',
    () async {
      final live = CreditsRemoteDataSourceImpl(
        config: const AppConfig(
          apiBaseUrl: 'https://example.invalid',
          usesMockData: false,
        ),
        apiBaseService: api,
      );
      when(
        () =>
            api.get<Map<String, dynamic>>(path: '/credits/usage-report/org-1'),
      ).thenAnswer(
        (_) async => const ApiResponseModel(
          data: <String, dynamic>{
            'data': <String, dynamic>{
              'balance': 44,
              'total_credited': 900,
              'total_used': 856,
            },
          },
          statusCode: 200,
        ),
      );

      final report = await live.getUsageReport('org-1');

      expect(report.balance, 44);
      expect(report.purchased, 900);
      expect(report.consumed, 856);
    },
  );
}
