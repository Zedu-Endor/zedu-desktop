import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockApiBaseService extends Mock implements ApiBaseService {}

void main() {
  late MockApiBaseService api;
  late MessageSearchService service;

  setUp(() {
    api = MockApiBaseService();
    service = MessageSearchService(api);
  });

  // Two groups, as the backend sends them: one per sender and channel.
  final payload = <String, dynamic>{
    'data': [
      {
        'user': {'user_name': 'Ada', 'avatar_url': 'https://cdn/ada.png'},
        'channel': {'channel_id': 'c1', 'channel_name': 'general'},
        'messages': [
          {
            'message_id': 'm1',
            'message': '<p>Deploy &amp; <b>ship</b></p>',
            'timestamp': '2026-11-04T09:00:00Z',
          },
          {
            'message_id': 'm3',
            'message': 'older',
            'timestamp': '2026-11-01T09:00:00Z',
          },
        ],
      },
      {
        'user': {'user_name': 'Grace', 'avatar_url': ''},
        'channel': {'channel_id': 'c2', 'channel_name': 'design'},
        'messages': [
          {
            'message_id': 'm2',
            'message': 'newest',
            'timestamp': '2026-11-05T09:00:00Z',
          },
          {'message_id': '', 'message': 'no id, dropped'},
        ],
      },
    ],
  };

  group('MessageSearchService (#2825)', () {
    test(
      'calls the organisation search with the query, newest first',
      () async {
        when(
          () => api.get<Map<String, dynamic>>(
            path: any(named: 'path'),
            queryParameters: any(named: 'queryParameters'),
          ),
        ).thenAnswer(
          (_) async => ApiResponseModel<Map<String, dynamic>>(
            data: payload,
            statusCode: 200,
          ),
        );

        final results = await service.search(
          orgId: 'org-1',
          query: 'deploy from:Ada',
        );

        verify(
          () => api.get<Map<String, dynamic>>(
            path: '/search/organisation/org-1',
            queryParameters: {'query': 'deploy from:Ada', 'sortBy': 'newest'},
          ),
        ).called(1);
        expect(results.map((r) => r.id), ['m2', 'm1', 'm3']);
        final ada = results[1];
        expect(ada.content, 'Deploy & ship');
        expect(ada.senderName, 'Ada');
        expect(ada.channelId, 'c1');
        expect(ada.channelName, 'general');
        expect(ada.senderAvatarUrl, 'https://cdn/ada.png');
        expect(results.first.senderAvatarUrl, isNull);
      },
    );

    test('treats a 404 as no results', () async {
      when(
        () => api.get<Map<String, dynamic>>(
          path: any(named: 'path'),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(const ApiFailure(message: 'Not found', statusCode: 404));

      expect(await service.search(orgId: 'org-1', query: 'x'), isEmpty);
    });

    test('passes other failures on', () async {
      when(
        () => api.get<Map<String, dynamic>>(
          path: any(named: 'path'),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(const ApiFailure(message: 'Down', statusCode: 500));

      expect(
        () => service.search(orgId: 'org-1', query: 'x'),
        throwsA(isA<ApiFailure>()),
      );
    });

    test('asks nothing without a workspace or a query', () async {
      expect(await service.search(orgId: '', query: 'x'), isEmpty);
      expect(await service.search(orgId: 'org-1', query: '  '), isEmpty);
      verifyNever(
        () => api.get<Map<String, dynamic>>(
          path: any(named: 'path'),
          queryParameters: any(named: 'queryParameters'),
        ),
      );
    });
  });

  test('flattenMessageSearchResults ignores a malformed payload', () {
    expect(flattenMessageSearchResults(null), isEmpty);
    expect(flattenMessageSearchResults({'not': 'a list'}), isEmpty);
    expect(flattenMessageSearchResults([42, 'x']), isEmpty);
  });
}
