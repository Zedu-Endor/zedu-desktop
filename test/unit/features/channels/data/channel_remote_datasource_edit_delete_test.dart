import '../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockApiBaseService extends Mock implements ApiBaseService {}

const _ok = ApiResponseModel<Map<String, dynamic>>(
  data: <String, dynamic>{},
  statusCode: 200,
);

void main() {
  late MockApiBaseService api;
  late ChannelRemoteDataSourceImpl datasource;

  setUp(() {
    api = MockApiBaseService();
    datasource = ChannelRemoteDataSourceImpl(
      apiBaseService: api,
      config: AppConfig(
        apiBaseUrl: 'https://example.test',
        usesMockData: false,
      ),
    );
  });

  group('editing and deleting channel messages (Ziki #2839)', () {
    test(
      'edit PUTs the new content to /threads/{thread}/channels/{channel}',
      () async {
        when(
          () => api.put<Map<String, dynamic>>(
            path: any(named: 'path'),
            data: any(named: 'data'),
          ),
        ).thenAnswer((_) async => _ok);

        await datasource.editChannelMessage(
          channelId: 'ch-1',
          threadId: 't-1',
          content: 'fixed',
        );

        verify(
          () => api.put<Map<String, dynamic>>(
            path: '/threads/t-1/channels/ch-1',
            data: {'content': 'fixed'},
          ),
        ).called(1);
      },
    );

    test('delete DELETEs /threads/{thread}/channels/{channel}', () async {
      when(
        () => api.delete<Map<String, dynamic>>(path: any(named: 'path')),
      ).thenAnswer((_) async => _ok);

      await datasource.deleteChannelMessage(channelId: 'ch-1', threadId: 't-1');

      verify(
        () => api.delete<Map<String, dynamic>>(
          path: '/threads/t-1/channels/ch-1',
        ),
      ).called(1);
    });
  });

  group('ChannelMessage.fromJson', () {
    test('reads the thread id and the sender id', () {
      final message = ChannelMessage.fromJson(const {
        'thread_id': 't-1',
        'user_id': 'u-1',
        'username': 'ada',
        'message': 'hi',
      });

      expect(message.threadId, 't-1');
      expect(message.userId, 'u-1');
    });

    test('falls back to id for the thread id', () {
      final message = ChannelMessage.fromJson(const {
        'id': 'm-1',
        'message': 'hi',
      });

      expect(message.threadId, 'm-1');
      expect(message.userId, isNull);
    });
  });
}
