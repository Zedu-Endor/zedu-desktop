import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

abstract class FilesRemoteDataSource {
  Future<FilesPage> fetchFiles(FilesQuery query);

  Future<List<FileFolder>> fetchFolders({
    required FilesScope view,
    String? parentId,
  });

  /// The download link of file [fileId], or empty when it has none.
  Future<String> fetchFileLink(String fileId);

  /// Downloads [url] to [savePath]. [onProgress] gets the bytes received and
  /// the total, which is -1 when the server does not say.
  Future<void> downloadFile({
    required String url,
    required String savePath,
    void Function(int received, int total)? onProgress,
  });

  /// Deletes file [fileId]: moves it to Deleted files, or removes it for good
  /// when [permanent].
  Future<void> deleteFile(String fileId, {bool permanent = false});

  /// Renames file [fileId] to [name].
  Future<void> renameFile(String fileId, String name);
}

/// Talks to the same `/files` endpoints as the web app. The server picks
/// the organisation from the signed-in session.
class FilesRemoteDataSourceImpl implements FilesRemoteDataSource {
  final ApiBaseService apiBaseService;

  /// Fetches file contents from their storage links. It is a plain client,
  /// so the session token is never sent to the storage host.
  final Dio downloadClient;

  FilesRemoteDataSourceImpl({required this.apiBaseService, Dio? downloadClient})
    : downloadClient = downloadClient ?? Dio();

  @override
  Future<FilesPage> fetchFiles(FilesQuery query) async {
    final response = await apiBaseService.get<Map<String, dynamic>>(
      path: '/files',
      queryParameters: query.toQueryParameters(),
    );
    final data = response.data['data'];
    final body = data is Map ? data : const <String, dynamic>{};
    final rawFiles = body['files'];
    final files = (rawFiles is List ? rawFiles : const <dynamic>[])
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => WorkspaceFile.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final pagination = body['pagination'];
    int pageValue(List<String> keys, int fallback) {
      if (pagination is! Map) return fallback;
      for (final key in keys) {
        final value = num.tryParse(pagination[key]?.toString() ?? '');
        if (value != null) return value.toInt();
      }
      return fallback;
    }

    final currentPage = pageValue(['current_page'], query.page);
    final totalPages = pageValue(['total_pages_count', 'total_pages'], 1);
    return FilesPage(
      files: files,
      currentPage: currentPage < 1 ? 1 : currentPage,
      totalPages: totalPages < 1 ? 1 : totalPages,
    );
  }

  @override
  Future<List<FileFolder>> fetchFolders({
    required FilesScope view,
    String? parentId,
  }) async {
    final response = await apiBaseService.get<Map<String, dynamic>>(
      path: '/files/folders',
      queryParameters: {
        'mode': view.apiMode,
        if (parentId != null && parentId.isNotEmpty) 'parent_id': parentId,
      },
    );
    final data = response.data['data'];
    final rawFolders = data is Map ? data['folders'] : null;
    return (rawFolders is List ? rawFolders : const <dynamic>[])
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => FileFolder.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<String> fetchFileLink(String fileId) async {
    final response = await apiBaseService.get<Map<String, dynamic>>(
      path: '/files/file/$fileId',
    );
    final data = response.data['data'];
    return data is Map ? data['file_link']?.toString().trim() ?? '' : '';
  }

  @override
  Future<void> downloadFile({
    required String url,
    required String savePath,
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      await downloadClient.download(
        url,
        savePath,
        onReceiveProgress: onProgress,
      );
    } on DioException catch (error) {
      throw ApiFailure.fromDioException(error);
    }
  }

  @override
  Future<void> deleteFile(String fileId, {bool permanent = false}) async {
    await apiBaseService.delete<dynamic>(
      path: '/files/file/$fileId',
      queryParameters: permanent ? const {'permanent': true} : null,
    );
  }

  @override
  Future<void> renameFile(String fileId, String name) async {
    await apiBaseService.put<dynamic>(
      path: '/files/file/$fileId',
      data: {'file_name': name},
    );
  }
}
