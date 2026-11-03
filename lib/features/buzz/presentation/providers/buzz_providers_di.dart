import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// The app's config, so it can be overridden in tests.
final buzzConfigProvider = Provider<AppConfig>((ref) => locator<AppConfig>());

/// The organisation the server creates meetings in: the signed-in user's
/// current one.
final buzzOrgSlugProvider = Provider<String>(
  (ref) =>
      ref.watch(authNotifierProvider).user?.currentOrganisationSlug.trim() ??
      '',
);

final buzzMeetingsRemoteDataSourceProvider =
    Provider<BuzzMeetingsRemoteDataSource>(
      (ref) => BuzzMeetingsRemoteDataSourceImpl(
        apiBaseService: locator<ApiBaseService>(),
      ),
    );

final buzzMeetingsRepositoryProvider = Provider<BuzzMeetingsRepository>(
  (ref) => BuzzMeetingsRepositoryImpl(
    remoteDataSource: ref.watch(buzzMeetingsRemoteDataSourceProvider),
  ),
);

final buzzMeetingsProvider =
    NotifierProvider<BuzzMeetingsNotifier, BuzzMeetingAction>(
      BuzzMeetingsNotifier.new,
    );
