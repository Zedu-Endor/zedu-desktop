import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

final channelRepositoryProvider = Provider<ChannelRepository>((ref) {
  final apiBaseService = locator<ApiBaseService>();
  final remoteDataSource = ChannelRemoteDataSourceImpl(
    apiBaseService: apiBaseService,
  );
  return ChannelRepositoryImpl(remoteDataSource: remoteDataSource);
});

class ChannelState {
  final List<Channel> channels;
  final bool isLoading;
  final String? errorMessage;

  const ChannelState({
    this.channels = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  ChannelState copyWith({
    List<Channel>? channels,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ChannelState(
      channels: channels ?? this.channels,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class ChannelNotifier extends Notifier<ChannelState> {
  @override
  ChannelState build() {
    ref.watch(channelScopeProvider);
    // Schedule fetch after build
    Future.microtask(() {
      if (ref.mounted) fetchChannels();
    });
    return const ChannelState();
  }

  Future<void> fetchChannels() async {
    final scope = ref.read(channelScopeProvider);
    final orgId = scope?.workspaceId;
    if (orgId == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    final repository = ref.read(channelRepositoryProvider);
    final result = await repository.fetchChannels(orgId);

    if (!ref.mounted || ref.read(channelScopeProvider) != scope) return;

    if (result is Success<List<Channel>>) {
      state = state.copyWith(isLoading: false, channels: result.value);
    } else if (result is Failure<List<Channel>>) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: result.error.message,
      );
    }
  }

  Future<bool> createChannel({
    required String name,
    required String description,
    required bool isPrivate,
    String? topic,
  }) async {
    final workspaceState = ref.read(workspaceProvider);
    final authState = ref.read(authNotifierProvider);
    final String? orgId = workspaceState.selectedWorkspace?.id;
    final String? username =
        authState.user?.username ?? authState.user?.email.split('@').first;

    if (orgId == null || username == null) return false;

    final repository = ref.read(channelRepositoryProvider);
    final result = await repository.createChannel(
      name: name,
      description: description,
      orgId: orgId,
      username: username,
      isPrivate: isPrivate,
      topic: topic,
    );

    if (result is Success<Channel>) {
      state = state.copyWith(channels: [...state.channels, result.value]);
      return true;
    } else {
      return false;
    }
  }

  Future<bool> updateChannelTopicOrDescription({
    required String channelId,
    String? topic,
    String? description,
  }) async {
    final repository = ref.read(channelRepositoryProvider);
    final result = await repository.updateChannelTopicOrDescription(
      channelId: channelId,
      topic: topic,
      description: description,
    );

    if (result is Success<void>) {
      // Update local state
      final updatedChannels = state.channels.map((c) {
        if (c.id == channelId) {
          return Channel(
            id: c.id,
            name: c.name,
            description: description ?? c.description,
            organisationId: c.organisationId,
            isPrivate: c.isPrivate,
            ownerId: c.ownerId,
            archived: c.archived,
            topic: topic ?? c.topic,
            unreadCount: c.unreadCount,
            membersCount: c.membersCount,
          );
        }
        return c;
      }).toList();
      state = state.copyWith(channels: updatedChannels);
      return true;
    }
    return false;
  }
}

final channelProvider = NotifierProvider<ChannelNotifier, ChannelState>(
  ChannelNotifier.new,
);
