import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../helpers/helpers.dart';

class _Api extends Mock implements ApiBaseService {}

class _FailingApi extends Mock implements ApiBaseService {}

const _payload = <String, dynamic>{
  'user': {
    'user_id': 'user-1',
    'user_name': 'Ada Lovelace',
    'avatar_url': 'https://example.com/ada.png',
    'default_avatar_url': 'https://example.com/default.png',
    'is_deactivated': false,
  },
  'messages': [
    {
      'message_id': 'message-1',
      'thread_id': 'thread-1',
      'message': 'the release is on friday',
      'timestamp': '2026-10-21T10:00:00Z',
    },
  ],
  'channel': {
    'channel_id': 'channel-1',
    'channel_name': 'general',
    'channel_type': 'channel',
  },
};

void main() {
  group('SearchResultModel', () {
    test('maps the backend payload to entity fields', () {
      final model = SearchResultModel.fromJson(_payload);

      expect(model.user.userId, 'user-1');
      expect(model.user.userName, 'Ada Lovelace');
      expect(model.user.isDeactivated, isFalse);
      expect(model.channel.channelId, 'channel-1');
      expect(model.channel.channelName, 'general');
      expect(model.messages.single.messageId, 'message-1');
      expect(model.messages.single.threadId, 'thread-1');
      expect(model.messages.single.text, 'the release is on friday');
    });

    test('tolerates a payload with missing sections', () {
      final model = SearchResultModel.fromJson(const <String, dynamic>{});

      expect(model.user.userName, isEmpty);
      expect(model.channel.channelId, isEmpty);
      expect(model.messages, isEmpty);
    });

    test('ignores message entries that are not objects', () {
      final model = SearchResultModel.fromJson(const <String, dynamic>{
        'messages': ['not-an-object', {'message_id': 'message-2'}],
      });

      expect(model.messages, hasLength(1));
      expect(model.messages.single.messageId, 'message-2');
    });
  });

  group('SearchRemoteDataSourceImpl', () {
    test('reads the results out of the success envelope', () async {
      final api = _Api();
      when(
        () => api.get<Map<String, dynamic>>(
          path: '/search/organisation/org-1',
          queryParameters: {'query': 'release', 'sortBy': 'relevance'},
        ),
      ).thenAnswer(
        (_) async => ApiResponseModel<Map<String, dynamic>>(
          data: {
            'data': [_payload],
          },
          statusCode: 200,
        ),
      );

      final results = await SearchRemoteDataSourceImpl(
        apiBaseService: api,
      ).searchOrganisationMessages(orgId: 'org-1', query: 'release');

      expect(results, hasLength(1));
      expect(results.single.channel.channelName, 'general');
    });

    test('returns nothing without a request when the query is blank', () async {
      final api = _Api();

      final results = await SearchRemoteDataSourceImpl(
        apiBaseService: api,
      ).searchOrganisationMessages(orgId: 'org-1', query: '   ');

      expect(results, isEmpty);
      verifyNever(() => api.get<Map<String, dynamic>>(path: any(named: 'path')));
    });

    test('returns nothing when the response carries no data list', () async {
      final api = _Api();
      when(
        () => api.get<Map<String, dynamic>>(
          path: any(named: 'path'),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => ApiResponseModel<Map<String, dynamic>>(
          data: const <String, dynamic>{'data': 'not-a-list'},
          statusCode: 200,
        ),
      );

      final results = await SearchRemoteDataSourceImpl(
        apiBaseService: api,
      ).searchOrganisationMessages(orgId: 'org-1', query: 'release');

      expect(results, isEmpty);
    });
  });

  group('SearchRepositoryImpl', () {
    test('maps models into entities', () async {
      final api = _Api();
      when(
        () => api.get<Map<String, dynamic>>(
          path: any(named: 'path'),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => ApiResponseModel<Map<String, dynamic>>(
          data: {
            'data': [_payload],
          },
          statusCode: 200,
        ),
      );

      final result = await SearchRepositoryImpl(
        remote: SearchRemoteDataSourceImpl(apiBaseService: api),
      ).searchOrganisationMessages(orgId: 'org-1', query: 'release');

      expect(result, isA<Success<List<SearchResult>>>());
      final success = result as Success<List<SearchResult>>;
      expect(success.value.single.user.userName, 'Ada Lovelace');
      expect(success.value.single.messages.single.text, 'the release is on friday');
    });

    test('reports a failure when the request throws', () async {
      final api = _FailingApi();
      when(
        () => api.get<Map<String, dynamic>>(
          path: any(named: 'path'),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/search/organisation/org-1'),
        ),
      );

      final result = await SearchRepositoryImpl(
        remote: SearchRemoteDataSourceImpl(apiBaseService: api),
      ).searchOrganisationMessages(orgId: 'org-1', query: 'release');

      expect(result, isA<Failure<List<SearchResult>>>());
    });

    test('does not call the backend without an organisation id', () async {
      final api = _Api();

      final result = await SearchRepositoryImpl(
        remote: SearchRemoteDataSourceImpl(apiBaseService: api),
      ).searchOrganisationMessages(orgId: '', query: 'release');

      expect(result, isA<Success<List<SearchResult>>>());
      verifyNever(() => api.get<Map<String, dynamic>>(path: any(named: 'path')));
    });
  });
}
