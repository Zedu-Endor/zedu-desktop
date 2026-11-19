import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

final messageSearchServiceProvider = Provider<MessageSearchService>(
  (ref) => MessageSearchService(locator<ApiBaseService>()),
);

/// What the Search messages dialog shows (#2825): the typed words, the
/// filters that are on, and the results of the last search.
class MessageSearchState {
  const MessageSearchState({
    this.text = '',
    this.filters = MessageSearchFilters.none,
    this.results = const AsyncData(<SearchResultModel>[]),
  });

  final String text;
  final MessageSearchFilters filters;
  final AsyncValue<List<SearchResultModel>> results;

  /// A search runs once there are words to look for or a filter to narrow by.
  bool get canSearch => text.trim().isNotEmpty || filters.activeCount > 0;

  MessageSearchState copyWith({
    String? text,
    MessageSearchFilters? filters,
    AsyncValue<List<SearchResultModel>>? results,
  }) => MessageSearchState(
    text: text ?? this.text,
    filters: filters ?? this.filters,
    results: results ?? this.results,
  );
}

class MessageSearchNotifier extends Notifier<MessageSearchState> {
  /// Each search gets a number; a reply to an older one is dropped, so slow
  /// answers never overwrite newer results.
  int _generation = 0;

  /// The clock the date filters count from; tests replace it.
  DateTime Function() now = DateTime.now;

  @override
  MessageSearchState build() {
    // Results from one workspace mean nothing in another.
    ref.watch(creditsOrgIdProvider);
    return const MessageSearchState();
  }

  void setText(String text) {
    state = state.copyWith(text: text);
    search();
  }

  void setFilters(MessageSearchFilters filters) {
    state = state.copyWith(filters: filters);
    search();
  }

  void clearFilters() => setFilters(MessageSearchFilters.none);

  /// Runs the search for the current words and filters.
  Future<void> search() async {
    final generation = ++_generation;
    if (!state.canSearch) {
      state = state.copyWith(results: const AsyncData([]));
      return;
    }
    final query = buildMessageSearchQuery(
      state.text,
      state.filters,
      now: now(),
    );
    state = state.copyWith(results: const AsyncLoading());
    try {
      final results = await ref
          .read(messageSearchServiceProvider)
          .search(orgId: ref.read(creditsOrgIdProvider), query: query);
      if (generation != _generation) return;
      state = state.copyWith(results: AsyncData(results));
    } catch (error, stack) {
      if (generation != _generation) return;
      state = state.copyWith(results: AsyncError(error, stack));
    }
  }
}

final messageSearchProvider =
    NotifierProvider.autoDispose<MessageSearchNotifier, MessageSearchState>(
      MessageSearchNotifier.new,
    );
