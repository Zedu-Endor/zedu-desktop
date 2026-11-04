import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../helpers/helpers.dart';

class MockApiBaseService extends Mock implements ApiBaseService {}

void main() {
  late MockApiBaseService api;
  late FilesRemoteDataSourceImpl datasource;

  setUp(() {
    api = MockApiBaseService();
    datasource = FilesRemoteDataSourceImpl(apiBaseService: api);
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

  group('restoreFile', () {
    test('sends PUT to the restore path of that file', () async {
      when(() => api.put<dynamic>(path: any(named: 'path'))).thenAnswer(
        (_) async =>
            const ApiResponseModel<dynamic>(statusCode: 200, data: null),
      );

      await datasource.restoreFile('f-1');

      verify(() => api.put<dynamic>(path: '/files/file/f-1/restore')).called(1);
    });

    test('passes a failure on to the caller', () async {
      const failure = ApiFailure(
        message: 'File not found',
        kind: ApiFailureKind.notFound,
      );
      when(() => api.put<dynamic>(path: any(named: 'path'))).thenThrow(failure);

      await expectLater(datasource.restoreFile('f-1'), throwsA(failure));
    });
  });
}
