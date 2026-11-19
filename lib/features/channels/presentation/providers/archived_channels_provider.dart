import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// The workspace's archived channels. The channel list leaves them out, so
/// the channel directory loads them from here to offer Unarchive.
class ArchivedChannelsNotifier extends AsyncNotifier<List<Channel>> {
  @override
  Future<List<Channel>> build() async {
    final orgId = ref.watch(
      workspaceProvider.select((s) => s.selectedWorkspace?.id),
    );
    if (orgId == null) return const [];

    final result = await ref
        .read(channelRepositoryProvider)
        .fetchArchivedChannels(orgId);

    return switch (result) {
      Success<List<Channel>>(:final value) => value,
      Failure<List<Channel>>(:final error) => throw error,
    };
  }
}

final archivedChannelsProvider =
    AsyncNotifierProvider<ArchivedChannelsNotifier, List<Channel>>(
      ArchivedChannelsNotifier.new,
      retry: (_, _) => null,
    );
