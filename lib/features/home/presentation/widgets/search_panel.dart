import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

final _hiddenBlocks = RegExp(
  r'<(script|style)\b[^>]*>[\s\S]*?</\1\s*>',
  caseSensitive: false,
);
final _anyTag = RegExp(r'<[a-zA-Z/][^>]*>');
final _anyEntity = RegExp(r'&(#[xX][0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);');

/// Turns a search hit's message content into readable text for the result
/// list. Web and mobile send messages as HTML: tags are converted to the same
/// Markdown the chat shows, script and style blocks are dropped instead of
/// shown, entities are decoded, and each line becomes its own paragraph so
/// separate lines are not run together. Plain text is returned unchanged.
/// Nothing in the content is ever run.
String searchResultText(String content) {
  final visible = content.replaceAll(_hiddenBlocks, '');
  if (_anyTag.hasMatch(visible)) {
    final paragraphs = [
      for (final line in htmlMessageToMarkdown(visible).split('\n'))
        if (line.trim().isNotEmpty) line.trim(),
    ];
    return paragraphs.join('\n\n');
  }
  if (_anyEntity.hasMatch(visible)) return decodeHtmlEntities(visible);
  return visible;
}

class SearchPanel extends StatefulWidget {
  final VoidCallback onClose;

  /// Finds messages for a query. Without it the panel shows placeholder
  /// results until it is connected to the search API (Ziki #62).
  final Future<List<String>> Function(String query)? search;

  const SearchPanel({super.key, required this.onClose, this.search});

  @override
  State<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends State<SearchPanel> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _results = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      // Mock search delay
    });

    final search = widget.search;
    if (search != null) {
      search(query).then(
        (results) {
          if (!mounted) return;
          setState(() {
            _isSearching = false;
            _results = results;
          });
        },
        onError: (Object _) {
          if (!mounted) return;
          setState(() {
            _isSearching = false;
            _results = [];
          });
        },
      );
      return;
    }

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _results = [
            'Found message matching "$query"',
            'Another result for "$query"',
            'Older message discussing "$query"',
          ];
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

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
                  tooltip: 'Close search',
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
              onSubmitted: _performSearch,
            ),
          ),
          Expanded(
            child: _isSearching
                ? Center(
                    child: CircularProgressIndicator(color: colors.primary),
                  )
                : _results.isEmpty
                ? Center(
                    child: Text(
                      _searchController.text.isEmpty
                          ? 'Enter a search term'
                          : 'No results found',
                      style: TextStyle(color: colors.textHint),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _results.length,
                    separatorBuilder: (context, index) =>
                        Divider(color: colors.divider),
                    itemBuilder: (context, index) {
                      return MessageBubble(
                        author: 'Jane Smith',
                        text: searchResultText(_results[index]),
                        timestamp: 'Yesterday',
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
