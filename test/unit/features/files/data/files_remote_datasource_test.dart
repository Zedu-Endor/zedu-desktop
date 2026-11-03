import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../helpers/helpers.dart';

class MockApiBaseService extends Mock implements ApiBaseService {}

class MockDio extends Mock implements Dio {}

void main() {
  late MockApiBaseService api;
  late MockDio downloadClient;
  late FilesRemoteDataSourceImpl datasource;

  setUp(() {
    api = MockApiBaseService();
    downloadClient = MockDio();
    datasource = FilesRemoteDataSourceImpl(
      apiBaseService: api,
      downloadClient: downloadClient,
    );
  });

  group('fetchFiles', () {
    test('sends the query and reads files and pagination', () async {
      when(
        () => api.get<Map<String, dynamic>>(
          path: '/files',
          queryParameters: {
            'mode': 'mine',
            'page': 2,
            'limit': 10,
            'folder_id': 'folder-1',
            'file_category': 'images',
            'date_modified': 'last_7_days',
            'search': 'logo',
          },
        ),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          statusCode: 200,
          data: {
            'data': {
              'files': [
                {
                  'id': 'f-1',
                  'file_name': 'logo.png',
                  'file_type': 'png',
                  'file_link': 'https://cdn.zedu.test/logo.png',
                  'size': 2048,
                  'user_id': 'u-1',
                  'uploader_display_name': 'Ada Lovelace',
                  'shared_in': 'general',
                  'updated_at': '2026-11-01T10:00:00Z',
                },
              ],
              'pagination': {'current_page': 2, 'total_pages_count': 3},
            },
          },
        ),
      );

      final page = await datasource.fetchFiles(
        const FilesQuery(
          view: FilesScope.mine,
          folderId: 'folder-1',
          category: FileCategory.images,
          dateModified: DateModifiedFilter.last7Days,
          search: ' logo ',
          page: 2,
        ),
      );

      expect(page.currentPage, 2);
      expect(page.totalPages, 3);
      final file = page.files.single;
      expect(file.name, 'logo.png');
      expect(file.isImage, isTrue);
      expect(file.size, 2048);
      expect(file.owner, 'Ada Lovelace');
      expect(file.sharedIn, 'general');
      expect(file.modifiedAt, DateTime.utc(2026, 11, 1, 10).toLocal());
    });

    test('returns an empty page when the body has no files', () async {
      when(
        () => api.get<Map<String, dynamic>>(
          path: '/files',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          statusCode: 200,
          data: {'data': null},
        ),
      );

      final page = await datasource.fetchFiles(const FilesQuery());

      expect(page.files, isEmpty);
      expect(page.totalPages, 1);
    });
  });

  group('fetchFolders', () {
    test('asks for the folders inside a parent', () async {
      when(
        () => api.get<Map<String, dynamic>>(
          path: '/files/folders',
          queryParameters: {'mode': 'trash', 'parent_id': 'folder-1'},
        ),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          statusCode: 200,
          data: {
            'data': {
              'folders': [
                {
                  'id': 'folder-2',
                  'name': 'docs',
                  'user_id': 'u-1',
                  'item_count': 4,
                  'created_at': '2026-11-01T00:00:00Z',
                },
              ],
            },
          },
        ),
      );

      final folders = await datasource.fetchFolders(
        view: FilesScope.trash,
        parentId: 'folder-1',
      );

      expect(folders.single.name, 'docs');
      expect(folders.single.itemCount, 4);
    });

    test('leaves out parent_id at the top level', () async {
      when(
        () => api.get<Map<String, dynamic>>(
          path: '/files/folders',
          queryParameters: {'mode': 'all'},
        ),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          statusCode: 200,
          data: {
            'data': {'folders': <dynamic>[]},
          },
        ),
      );

      expect(await datasource.fetchFolders(view: FilesScope.all), isEmpty);
    });
  });

  group('fetchFileLink', () {
    test('reads the link from the file details', () async {
      when(
        () => api.get<Map<String, dynamic>>(path: '/files/file/f-1'),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          statusCode: 200,
          data: {
            'data': {'file_link': ' https://cdn.zedu.test/logo.png '},
          },
        ),
      );

      expect(
        await datasource.fetchFileLink('f-1'),
        'https://cdn.zedu.test/logo.png',
      );
    });

    test('is empty when the details have no link', () async {
      when(
        () => api.get<Map<String, dynamic>>(path: '/files/file/f-1'),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          statusCode: 200,
          data: {'data': null},
        ),
      );

      expect(await datasource.fetchFileLink('f-1'), isEmpty);
    });
  });

  group('downloadFile', () {
    test('saves the link to the chosen path and reports progress', () async {
      when(
        () => downloadClient.download(
          any(),
          any<dynamic>(),
          onReceiveProgress: any(named: 'onReceiveProgress'),
        ),
      ).thenAnswer((invocation) async {
        final onProgress =
            invocation.namedArguments[#onReceiveProgress] as ProgressCallback;
        onProgress(50, 100);
        return Response<dynamic>(requestOptions: RequestOptions());
      });
      final progress = <(int, int)>[];

      await datasource.downloadFile(
        url: 'https://cdn.zedu.test/logo.png',
        savePath: '/Users/ada/Downloads/logo.png',
        onProgress: (received, total) => progress.add((received, total)),
      );

      verify(
        () => downloadClient.download(
          'https://cdn.zedu.test/logo.png',
          '/Users/ada/Downloads/logo.png',
          onReceiveProgress: any(named: 'onReceiveProgress'),
        ),
      ).called(1);
      expect(progress, [(50, 100)]);
    });

    test('turns a failed request into an ApiFailure', () async {
      when(
        () => downloadClient.download(
          any(),
          any<dynamic>(),
          onReceiveProgress: any(named: 'onReceiveProgress'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/logo.png'),
          response: Response<dynamic>(
            requestOptions: RequestOptions(path: '/logo.png'),
            statusCode: 404,
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      await expectLater(
        datasource.downloadFile(url: 'https://cdn.zedu.test/x', savePath: '/x'),
        throwsA(
          isA<ApiFailure>().having((e) => e.statusCode, 'statusCode', 404),
        ),
      );
    });
  });
}
