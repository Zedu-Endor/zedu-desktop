import '../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockApiBaseService extends Mock implements ApiBaseService {}

void main() {
  group('ChannelRemoteDataSourceImpl.toggleStarChannel', () {
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

    void stubResponse(Map<String, dynamic> body) {
      when(
        () => mockApi.post<Map<String, dynamic>>(
          path: '/organisations/org-1/channels/ch-1/star',
        ),
      ).thenAnswer(
        (_) async =>
            ApiResponseModel<Map<String, dynamic>>(data: body, statusCode: 200),
      );
    }

    test('posts to the channel star path and returns the new state', () async {
      stubResponse({
        'data': {'is_starred': true, 'channel_id': 'ch-1'},
      });

      final starred = await datasource.toggleStarChannel(
        orgId: 'org-1',
        channelId: 'ch-1',
      );

      expect(starred, isTrue);
      verify(
        () => mockApi.post<Map<String, dynamic>>(
          path: '/organisations/org-1/channels/ch-1/star',
        ),
      ).called(1);
    });

    test('returns false when the channel was unstarred', () async {
      stubResponse({
        'data': {'is_starred': false, 'channel_id': 'ch-1'},
      });

      expect(
        await datasource.toggleStarChannel(orgId: 'org-1', channelId: 'ch-1'),
        isFalse,
      );
    });

    test('fails when the response has no star state', () async {
      stubResponse({'data': null});

      await expectLater(
        datasource.toggleStarChannel(orgId: 'org-1', channelId: 'ch-1'),
        throwsException,
      );
    });

    test('passes a request failure on to the caller', () async {
      const failure = ApiFailure(
        message: 'channel not found',
        kind: ApiFailureKind.notFound,
      );
      when(
        () => mockApi.post<Map<String, dynamic>>(path: any(named: 'path')),
      ).thenThrow(failure);

      await expectLater(
        datasource.toggleStarChannel(orgId: 'org-1', channelId: 'ch-1'),
        throwsA(failure),
      );
    });
  });

  group('ChannelRemoteDataSourceImpl.updateChannelTopicOrDescription', () {
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

    void stubPatch(Map<String, dynamic> body) {
      when(
        () => mockApi.patch<Map<String, dynamic>>(
          path: '/channels/ch-1',
          data: body,
        ),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          data: {'status': 'success'},
          statusCode: 200,
        ),
      );
    }

    test('saves the topic with PATCH /channels/{id}', () async {
      stubPatch({'topic': 'Release notes'});

      await datasource.updateChannelTopicOrDescription(
        channelId: 'ch-1',
        topic: 'Release notes',
      );

      verify(
        () => mockApi.patch<Map<String, dynamic>>(
          path: '/channels/ch-1',
          data: {'topic': 'Release notes'},
        ),
      ).called(1);
    });

    test('saves the description with PATCH /channels/{id}', () async {
      stubPatch({'description': 'Where we plan launches'});

      await datasource.updateChannelTopicOrDescription(
        channelId: 'ch-1',
        description: 'Where we plan launches',
      );

      verify(
        () => mockApi.patch<Map<String, dynamic>>(
          path: '/channels/ch-1',
          data: {'description': 'Where we plan launches'},
        ),
      ).called(1);
    });
  });

  group('ChannelRemoteDataSourceImpl.fetchChannels (Ziki #1433)', () {
    late MockApiBaseService mockApi;
    late ChannelRemoteDataSourceImpl datasource;
    const pageSize = ChannelRemoteDataSourceImpl.channelPageSize;

    setUp(() {
      mockApi = MockApiBaseService();
      datasource = ChannelRemoteDataSourceImpl(
        apiBaseService: mockApi,
        config: AppConfig(
          apiBaseUrl: 'https://example.test',
          usesMockData: false,
        ),
      );
      // fetchChannels also merges unread counts from user-channels.
      when(
        () => mockApi.get<Map<String, dynamic>>(
          path: '/organisations/org-1/user-channels',
        ),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          data: {'data': <Map<String, dynamic>>[]},
          statusCode: 200,
        ),
      );
    });

    List<Map<String, dynamic>> channels(int from, int count) => [
      for (var i = from; i < from + count; i++)
        {'channels_id': 'c$i', 'name': 'channel-$i'},
    ];

    void stubPage(
      int page,
      List<Map<String, dynamic>> data, {
      Map<String, dynamic>? pagination,
    }) {
      when(
        () => mockApi.get<Map<String, dynamic>>(
          path: '/organisations/org-1/channels',
          queryParameters: {'page': page, 'limit': pageSize},
        ),
      ).thenAnswer(
        (_) async => ApiResponseModel<Map<String, dynamic>>(
          data: {'data': data, 'pagination': ?pagination},
          statusCode: 200,
        ),
      );
    }

    test('loads every page, not just the first', () async {
      stubPage(
        1,
        channels(0, pageSize),
        pagination: {'current_page': 1, 'total_pages': 2},
      );
      stubPage(
        2,
        channels(pageSize, 5),
        pagination: {'current_page': 2, 'total_pages': 2},
      );

      final result = await datasource.fetchChannels('org-1');

      expect(result.length, pageSize + 5);
      expect(result.first.id, 'c0');
      expect(result.last.id, 'c${pageSize + 4}');
    });

    test('stops at the last page the server reports', () async {
      stubPage(
        1,
        channels(0, pageSize),
        pagination: {'current_page': 1, 'total_pages': 1},
      );

      final result = await datasource.fetchChannels('org-1');

      expect(result.length, pageSize);
      verify(
        () => mockApi.get<Map<String, dynamic>>(
          path: '/organisations/org-1/channels',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).called(1);
    });

    test('a short page without pagination info is the last one', () async {
      stubPage(1, channels(0, 3));

      expect((await datasource.fetchChannels('org-1')).length, 3);
      verify(
        () => mockApi.get<Map<String, dynamic>>(
          path: '/organisations/org-1/channels',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).called(1);
    });

    test('an empty organisation has no channels', () async {
      stubPage(1, const []);

      expect(await datasource.fetchChannels('org-1'), isEmpty);
    });

    test('a list that never ends stops at the page cap', () async {
      when(
        () => mockApi.get<Map<String, dynamic>>(
          path: '/organisations/org-1/channels',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => ApiResponseModel<Map<String, dynamic>>(
          data: {'data': channels(0, pageSize)},
          statusCode: 200,
        ),
      );

      final result = await datasource.fetchChannels('org-1');

      expect(
        result.length,
        pageSize * ChannelRemoteDataSourceImpl.maxChannelPages,
      );
    });
  });

  group('ChannelRemoteDataSourceImpl in the mock build (#3474)', () {
    late MockApiBaseService mockApi;
    late ChannelRemoteDataSourceImpl datasource;

    setUp(() {
      mockApi = MockApiBaseService();
      datasource = ChannelRemoteDataSourceImpl(
        apiBaseService: mockApi,
        config: AppConfig(
          apiBaseUrl: 'https://example.test',
          usesMockData: true,
        ),
      );
    });

    test('lists no channels and sends no request', () async {
      expect(await datasource.fetchChannels('org-1'), isEmpty);
      verifyNever(
        () => mockApi.get<Map<String, dynamic>>(
          path: any(named: 'path'),
          queryParameters: any(named: 'queryParameters'),
        ),
      );
    });

    test('refuses a write without sending a request', () async {
      await expectLater(
        datasource.joinChannel('ch-1'),
        throwsA(isA<ApiFailure>()),
      );
      verifyNever(
        () => mockApi.post<Map<String, dynamic>>(
          path: any(named: 'path'),
          data: any(named: 'data'),
        ),
      );
    });
  });
}
