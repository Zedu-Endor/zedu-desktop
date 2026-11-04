import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

final filesRemoteDataSourceProvider = Provider<FilesRemoteDataSource>(
  (ref) => FilesRemoteDataSourceImpl(apiBaseService: locator<ApiBaseService>()),
);

final filesRepositoryProvider = Provider<FilesRepository>(
  (ref) => FilesRepositoryImpl(
    remoteDataSource: ref.watch(filesRemoteDataSourceProvider),
  ),
);

final filesProvider = NotifierProvider<FilesNotifier, FilesState>(
  FilesNotifier.new,
);

final filesListProvider = AsyncNotifierProvider<FilesListNotifier, FilesPage>(
  FilesListNotifier.new,
);

final foldersListProvider =
    AsyncNotifierProvider<FoldersListNotifier, FoldersPage>(
      FoldersListNotifier.new,
    );

final filesActionsProvider =
    NotifierProvider<FilesActionsNotifier, FilesActionsState>(
      FilesActionsNotifier.new,
    );

final saveLocationPickerProvider = Provider<SaveLocationPicker>(
  (ref) =>
      (fileName) => FilePicker.saveFile(
        dialogTitle: 'Save file',
        fileName: fileName,
        lockParentWindow: true,
      ),
);

final fileDownloadsProvider =
    NotifierProvider<FileDownloadsNotifier, Map<String, double?>>(
      FileDownloadsNotifier.new,
    );

final fileDeletionsProvider =
    NotifierProvider<FileDeletionsNotifier, Set<String>>(
      FileDeletionsNotifier.new,
    );

final fileRenamesProvider = NotifierProvider<FileRenamesNotifier, Set<String>>(
  FileRenamesNotifier.new,
);
