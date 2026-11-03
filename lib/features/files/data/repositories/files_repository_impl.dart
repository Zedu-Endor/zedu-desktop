import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class FilesRepositoryImpl implements FilesRepository {
  final FilesRemoteDataSource remoteDataSource;

  FilesRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Result<FilesPage>> fetchFiles(FilesQuery query) async {
    try {
      return Success(await remoteDataSource.fetchFiles(query));
    } on ApiFailure catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(ApiFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<List<FileFolder>>> fetchFolders({
    required FilesScope view,
    String? parentId,
  }) async {
    try {
      return Success(
        await remoteDataSource.fetchFolders(view: view, parentId: parentId),
      );
    } on ApiFailure catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(ApiFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> downloadFile({
    required WorkspaceFile file,
    required String savePath,
    void Function(double? progress)? onProgress,
  }) async {
    try {
      final link = file.link.isNotEmpty
          ? file.link
          : await remoteDataSource.fetchFileLink(file.id);
      if (link.isEmpty) {
        return const Failure(
          ApiFailure(
            message: 'This file has no download link.',
            kind: ApiFailureKind.client,
          ),
        );
      }
      await remoteDataSource.downloadFile(
        url: link,
        savePath: savePath,
        onProgress: onProgress == null
            ? null
            : (received, total) =>
                  onProgress(total > 0 ? received / total : null),
      );
      return const Success(null);
    } on ApiFailure catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(ApiFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> deleteFile(
    String fileId, {
    bool permanent = false,
  }) async {
    try {
      await remoteDataSource.deleteFile(fileId, permanent: permanent);
      return const Success(null);
    } on ApiFailure catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(ApiFailure(message: e.toString()));
    }
  }
}
