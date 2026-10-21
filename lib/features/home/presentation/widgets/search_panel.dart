import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class SearchPanel extends ConsumerStatefulWidget {
  final VoidCallback onClose;

  /// Called when a result is picked. Defaults to opening the channel the
  /// result was found in.
  final void Function(SearchResult result)? onResultSelected;

  const SearchPanel({
    super.key,
    required this.onClose,
    this.onResultSelected,
  });

  @override
  ConsumerState<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends ConsumerState<SearchPanel> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    final orgId = ref.read(authNotifierProvider).user?.currentOrg ?? '';
    ref
        .read(searchNotifierProvider.notifier)
        .search(orgId: orgId, query: query);
  }

  void _selectResult(SearchResult result) {
    final onResultSelected = widget.onResultSelected;
    if (onResultSelected != null) {
      onResultSelected(result);
      return;
    }

    final channelId = result.channel.channelId;
    if (channelId.isNotEmpty) {
      ref.read(activeChatProvider.notifier).selectChannel(channelId);
    }
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = ref.watch(searchNotifierProvider);

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(left: BorderSide(color: colors.divider)),
      ),
      child: Column(
        children: [
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.divider)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Search',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: widget.onClose,
                  icon: Icon(Icons.close, color: colors.textHint),
                  splashRadius: 20,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search messages...',
                hintStyle: TextStyle(color: colors.textHint),
                prefixIcon: Icon(Icons.search, color: colors.textHint),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colors.primary),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: _performSearch,
            ),
          ),
          Expanded(child: _buildBody(context, state)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, SearchState state) {
    final colors = context.colors;

    if (state.isLoading) {
      return Center(
        child: CircularProgressIndicator(color: colors.primary),
      );
    }

    if (state.status == SearchStatus.error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            state.error ?? 'Search failed. Please try again.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textHint),
          ),
        ),
      );
    }

    if (state.results.isEmpty) {
      return Center(
        child: Text(
          state.query.trim().isEmpty
              ? 'Enter a search term'
              : 'No results found',
          style: TextStyle(color: colors.textHint),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: state.results.length,
      separatorBuilder: (context, index) => Divider(color: colors.divider),
      itemBuilder: (context, index) {
        final result = state.results[index];
        final messages = result.messages;
        final text = messages.isEmpty ? '' : messages.first.text;
        final timestamp = messages.isEmpty ? '' : messages.first.timestamp;

        return InkWell(
          key: Key('search_result_${result.channel.channelId}'),
          onTap: () => _selectResult(result),
          child: MessageBubble(
            author: result.user.userName,
            text: text,
            timestamp: _formatTimestamp(timestamp),
          ),
        );
      },
    );
  }

  /// Renders the backend timestamp in a short, readable form.
  String _formatTimestamp(String raw) {
    if (raw.isEmpty) return '';

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;

    final local = parsed.toLocal();
    final now = DateTime.now();
    final isToday =
        local.year == now.year && local.month == now.month && local.day == now.day;

    final time =
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';

    if (isToday) return time;

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year} $time';
  }
}
