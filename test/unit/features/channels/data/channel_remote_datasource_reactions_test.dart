import '../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockApiBaseService extends Mock implements ApiBaseService {}

void main() {
  group('ChannelRemoteDataSourceImpl reactions', () {
    late MockApiBaseService mockApi;
    late ChannelRemoteDataSourceImpl datasource;

    setUp(() {
      mockApi = MockApiBaseService();
      datasource = ChannelRemoteDataSourceImpl(
        apiBaseService: mockApi,
        config: AppConfig(
          apiBaseUrl: 'https://example.test',
          usesMockData: false,
        ),
      );
    });

    group('fetchReactionUsers', () {
      test(
        'reads /reactions/{id}/thread/{thread} and flattens usernames',
        () async {
          when(
            () => mockApi.get<Map<String, dynamic>>(
              path: '/reactions/r-1/thread/t-1',
            ),
          ).thenAnswer(
            (_) async => ApiResponseModel<Map<String, dynamic>>(
              data: {
                'data': {
                  'usernames': [
                    'ada',
                    {'username': 'gold'},
                    {
                      'profile': {'username': 'nested'},
                    },
                    {'username': ''},
                  ],
                },
              },
              statusCode: 200,
            ),
          );

          final users = await datasource.fetchReactionUsers(
            reactionId: 'r-1',
            threadId: 't-1',
          );

          expect(users, ['ada', 'gold', 'nested']);
        },
      );

      test('returns an empty list when there is no data', () async {
        when(
          () => mockApi.get<Map<String, dynamic>>(
            path: '/reactions/r-1/thread/t-1',
          ),
        ).thenAnswer(
          (_) async => ApiResponseModel<Map<String, dynamic>>(
            data: {'data': null},
            statusCode: 200,
          ),
        );

        expect(
          await datasource.fetchReactionUsers(
            reactionId: 'r-1',
            threadId: 't-1',
          ),
          isEmpty,
        );
      });
    });

    group('toggleReaction', () {
      test('posts the toggle body and reports reacted when echoed', () async {
        when(
          () => mockApi.post<Map<String, dynamic>>(
            path: '/reactions/ch-1',
            data: {'reaction': '👍', 'thread_id': 't-1', 'type': 'thread'},
          ),
        ).thenAnswer(
          (_) async => ApiResponseModel<Map<String, dynamic>>(
            data: {
              'data': {'reaction': '👍', 'reaction_id': 'r-1'},
            },
            statusCode: 200,
          ),
        );

        final reacted = await datasource.toggleReaction(
          channelId: 'ch-1',
          threadId: 't-1',
          emoji: '👍',
        );

        expect(reacted, isTrue);
        verify(
          () => mockApi.post<Map<String, dynamic>>(
            path: '/reactions/ch-1',
            data: {'reaction': '👍', 'thread_id': 't-1', 'type': 'thread'},
          ),
        ).called(1);
      });

      test('reports removed when the backend returns no reaction', () async {
        when(
          () => mockApi.post<Map<String, dynamic>>(
            path: '/reactions/ch-1',
            data: any(named: 'data'),
          ),
        ).thenAnswer(
          (_) async => ApiResponseModel<Map<String, dynamic>>(
            data: {'data': null},
            statusCode: 200,
          ),
        );

        expect(
          await datasource.toggleReaction(
            channelId: 'ch-1',
            threadId: 't-1',
            emoji: '👍',
          ),
          isFalse,
        );
      });
    });
  });
}
