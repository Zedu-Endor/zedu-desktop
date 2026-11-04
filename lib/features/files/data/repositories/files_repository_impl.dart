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
  Future<Result<FoldersPage>> fetchFolders({
    required FilesScope view,
    String? parentId,
    int page = 1,
  }) async {
    try {
      return Success(
        await remoteDataSource.fetchFolders(
          view: view,
          parentId: parentId,
          page: page,
        ),
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
  }) => _guard(() async {
    final link = file.link.isNotEmpty
        ? file.link
        : await remoteDataSource.fetchFileLink(file.id);
    if (link.isEmpty) {
      throw const ApiFailure(
        message: 'This file has no download link.',
        kind: ApiFailureKind.client,
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
  });

  @override
  Future<Result<WorkspaceFile>> uploadFile(XFile file) =>
      _guard(() => remoteDataSource.uploadFile(file));

  @override
  Future<Result<void>> createFolder({
    required String name,
    required String orgId,
    String? parentId,
  }) => _guard(
    () => remoteDataSource.createFolder(
      name: name,
      orgId: orgId,
      parentId: parentId,
    ),
  );

  Future<Result<T>> _guard<T>(Future<T> Function() call) async {
    try {
      return Success(await call());
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

  @override
  Future<Result<void>> renameFile(String fileId, String name) async {
    try {
      await remoteDataSource.renameFile(fileId, name);
      return const Success(null);
    } on ApiFailure catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(ApiFailure(message: e.toString()));
    }
  }
}
