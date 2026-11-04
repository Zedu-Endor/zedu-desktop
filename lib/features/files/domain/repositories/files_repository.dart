import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

abstract class FilesRepository {
  Future<Result<FilesPage>> fetchFiles(FilesQuery query);

  /// Folders in [view], inside [parentId] or at the top level when null.
  Future<Result<FoldersPage>> fetchFolders({
    required FilesScope view,
    String? parentId,
    int page = 1,
  });

  /// Uploads [file] to the signed-in user's files.
  Future<Result<WorkspaceFile>> uploadFile(XFile file);

  /// Creates a folder inside [parentId], or at the top level when null.
  Future<Result<void>> createFolder({
    required String name,
    required String orgId,
    String? parentId,
  });

  /// Saves [file] to [savePath]. Uses the file's own link, or asks the server
  /// for it when the list did not include one. [onProgress] gets the share
  /// downloaded, from 0 to 1, or null while the size is unknown.
  Future<Result<void>> downloadFile({
    required WorkspaceFile file,
    required String savePath,
    void Function(double? progress)? onProgress,
  });

  /// Deletes [fileId]: moves it to Deleted files, or removes it for good when
  /// [permanent].
  Future<Result<void>> deleteFile(String fileId, {bool permanent = false});

  /// Renames [fileId] to [name].
  Future<Result<void>> renameFile(String fileId, String name);
}
