import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

abstract class FilesRemoteDataSource {
  Future<FilesPage> fetchFiles(FilesQuery query);

  Future<List<FileFolder>> fetchFolders({
    required FilesScope view,
    String? parentId,
  });

  /// Brings a file back from the trash.
  Future<void> restoreFile(String fileId);
}

/// Talks to the same `/files` endpoints as the web app. The server picks
/// the organisation from the signed-in session.
class FilesRemoteDataSourceImpl implements FilesRemoteDataSource {
  final ApiBaseService apiBaseService;

  FilesRemoteDataSourceImpl({required this.apiBaseService});

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
  Future<void> restoreFile(String fileId) async {
    await apiBaseService.put<dynamic>(path: '/files/file/$fileId/restore');
  }
}
