import '../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockApiBaseService extends Mock implements ApiBaseService {}

void main() {
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

  void answer(
    Object? data, {
    Object? pagination,
    int page = 1,
    int limit = 50,
  }) {
    when(
      () => mockApi.get<Map<String, dynamic>>(
        path: '/threads/channels/ch-1',
        queryParameters: {'page': page, 'limit': limit},
      ),
    ).thenAnswer(
      (_) async => ApiResponseModel<Map<String, dynamic>>(
        data: {'data': data, 'pagination': ?pagination},
        statusCode: 200,
      ),
    );
  }

  Map<String, dynamic> thread(String id) => {
    'thread_id': id,
    'username': 'ada',
    'message': 'message $id',
  };

  test('fetchChannelMessages reads /threads/channels/{id}', () async {
    answer([thread('t-1')]);

    final page = await datasource.fetchChannelMessages('ch-1');

    expect(page.messages.single.text, 'message t-1');
    expect(page.messages.single.id, 't-1');
  });

  test('fetchChannelMessages returns an empty last page for none', () async {
    answer(null);

    final page = await datasource.fetchChannelMessages('ch-1');

    expect(page.messages, isEmpty);
    expect(page.hasMore, isFalse);
  });

  test('fetchChannelMessages throws on a malformed response', () async {
    answer({'not': 'a list'});

    expect(datasource.fetchChannelMessages('ch-1'), throwsA(isA<TypeError>()));
  });

  test('fetchChannelMessages walks a two-page thread response', () async {
    answer(
      [thread('t-4'), thread('t-3')],
      pagination: {
        'current_page': 1,
        'page_count': 2,
        'total_pages_count': 2,
        'summary_count': 4,
      },
      limit: 2,
    );
    answer(
      [thread('t-2'), thread('t-1')],
      pagination: {
        'current_page': 2,
        'page_count': 2,
        'total_pages_count': 2,
        'summary_count': 4,
      },
      page: 2,
      limit: 2,
    );

    final first = await datasource.fetchChannelMessages('ch-1', limit: 2);
    final second = await datasource.fetchChannelMessages(
      'ch-1',
      page: 2,
      limit: 2,
    );

    expect(first.messages.map((m) => m.id), ['t-4', 't-3']);
    expect(first.hasMore, isTrue);
    expect(second.messages.map((m) => m.id), ['t-2', 't-1']);
    expect(second.hasMore, isFalse);
  });

  test('fetchChannelMessages trusts a has_more flag', () async {
    answer([thread('t-1')], pagination: {'has_more': true});

    expect((await datasource.fetchChannelMessages('ch-1')).hasMore, isTrue);
  });

  test(
    'fetchChannelMessages reads the backend total_pages_count block',
    () async {
      answer(
        [thread('t-2'), thread('t-1')],
        pagination: {
          'current_page': 1,
          'page_count': 2,
          'total_pages_count': 3,
          'summary_count': 6,
        },
        limit: 2,
      );

      final page = await datasource.fetchChannelMessages('ch-1', limit: 2);

      expect(page.hasMore, isTrue);
    },
  );

  test('fetchChannelMessages treats a full page as more without a '
      'pagination block', () async {
    answer([thread('t-2'), thread('t-1')], limit: 2);

    final page = await datasource.fetchChannelMessages('ch-1', limit: 2);

    expect(page.hasMore, isTrue);
  });

  test('fetchChannelMessages treats a short page as the last without a '
      'pagination block', () async {
    answer([thread('t-1')], limit: 2);

    final page = await datasource.fetchChannelMessages('ch-1', limit: 2);

    expect(page.hasMore, isFalse);
  });

  test('fetchChannelMessages ignores a pagination block of the wrong '
      'shape', () async {
    answer([thread('t-1')], pagination: [1, 2]);

    final page = await datasource.fetchChannelMessages('ch-1');

    expect(page.hasMore, isFalse);
  });
}
