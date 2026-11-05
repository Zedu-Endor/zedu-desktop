import '../../../../helpers/helpers.dart';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockApiBaseService extends Mock implements ApiBaseService {}

void main() {
  group('CreditsRemoteDataSourceImpl', () {
    late MockApiBaseService mockApi;

    setUp(() {
      mockApi = MockApiBaseService();
    });

    group('getUsage', () {
      test('returns mock usage when usesMockData is true', () async {
        final datasource = CreditsRemoteDataSourceImpl(
          config: const AppConfig(
            apiBaseUrl: 'https://api.example.com',
            usesMockData: true,
          ),
          apiBaseService: mockApi,
        );

        final result = await datasource.getUsage('org-123');

        expect(result.balance, 10);
        expect(result.totalPurchased, 10);
        expect(result.totalConsumed, 0);
        verifyNever(
          () => mockApi.get<Map<String, dynamic>>(path: any(named: 'path')),
        );
      });

      test(
        'fetches balance from /credits/usage-report/$orgId when available',
        () async {
          final datasource = CreditsRemoteDataSourceImpl(
            config: const AppConfig(
              apiBaseUrl: 'https://api.example.com',
              usesMockData: false,
            ),
            apiBaseService: mockApi,
          );

          when(
            () => mockApi.get<Map<String, dynamic>>(
              path: '/credits/usage-report/org-123',
            ),
          ).thenAnswer(
            (_) async => ApiResponseModel<Map<String, dynamic>>(
              data: {
                'data': {
                  'balance': 1500,
                  'total_credited': 2000,
                  'total_used': 500,
                },
              },
              statusCode: 200,
              status: 'success',
            ),
          );

          final result = await datasource.getUsage('org-123');

          expect(result.balance, 1500);
          expect(result.totalPurchased, 2000);
          expect(result.totalConsumed, 500);
        },
      );

      test(
        'gracefully handles list data from /credits/usage/$orgId without throwing TypeError',
        () async {
          final datasource = CreditsRemoteDataSourceImpl(
            config: const AppConfig(
              apiBaseUrl: 'https://api.example.com',
              usesMockData: false,
            ),
            apiBaseService: mockApi,
          );

          when(
            () => mockApi.get<Map<String, dynamic>>(
              path: '/credits/usage-report/org-123',
            ),
          ).thenThrow(Exception('Report route unavailable'));

          when(
            () => mockApi.get<Map<String, dynamic>>(
              path: '/credits/usage/org-123',
            ),
          ).thenAnswer(
            (_) async => ApiResponseModel<Map<String, dynamic>>(
              data: {
                'data': [
                  {'id': '1', 'amount': 10, 'agent_name': 'Agent A'},
                ],
              },
              statusCode: 200,
              status: 'success',
            ),
          );

          final result = await datasource.getUsage('org-123');

          expect(result.balance, 0);
          expect(result.totalPurchased, 0);
          expect(result.totalConsumed, 0);
        },
      );
    });

    group('CreditUsageModel.fromJson', () {
      test('parses total_credited and total_used properly', () {
        final model = CreditUsageModel.fromJson({
          'balance': 250,
          'total_credited': 1000,
          'total_used': 750,
        });

        expect(model.balance, 250);
        expect(model.totalPurchased, 1000);
        expect(model.totalConsumed, 750);
      });
    });

    group('CreditUsageReportModel.fromJson', () {
      test('parses total_credited and total_used fallback fields', () {
        final model = CreditUsageReportModel.fromJson({
          'balance': 500,
          'total_credited': 1200,
          'total_used': 700,
          'period_label': 'Last 30 days',
        });

        expect(model.balance, 500);
        expect(model.purchased, 1200);
        expect(model.consumed, 700);
        expect(model.periodLabel, 'Last 30 days');
      });
    });
  });
}
