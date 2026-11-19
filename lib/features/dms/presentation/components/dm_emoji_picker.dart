import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class DmEmojiPicker extends ConsumerStatefulWidget {
  final ValueChanged<String> onEmojiSelected;
  final VoidCallback onClose;

  const DmEmojiPicker({
    super.key,
    required this.onEmojiSelected,
    required this.onClose,
  });

  @override
  ConsumerState<DmEmojiPicker> createState() => _DmEmojiPickerState();
}

class _DmEmojiPickerState extends ConsumerState<DmEmojiPicker> {
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  int _selectedIndex = 0;
  bool _hasFocus = false;
  double _rowExtent = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  /// Remembers [emoji] for the Recently used row, then reports it.
  void _select(String emoji) {
    ref.read(recentEmojisProvider.notifier).add(emoji);
    widget.onEmojiSelected(emoji);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      widget.onClose();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      _select(_emojis[_selectedIndex]);
      return KeyEventResult.handled;
    }

    final nextIndex = switch (key) {
      LogicalKeyboardKey.arrowLeft => _selectedIndex - 1,
      LogicalKeyboardKey.arrowRight => _selectedIndex + 1,
      LogicalKeyboardKey.arrowUp => _selectedIndex - 8,
      LogicalKeyboardKey.arrowDown => _selectedIndex + 8,
      _ => _selectedIndex,
    };
    if (nextIndex == _selectedIndex) return KeyEventResult.ignored;
    if (nextIndex >= 0 && nextIndex < _emojis.length) {
      setState(() => _selectedIndex = nextIndex);
      WidgetsBinding.instance.addPostFrameCallback((_) => _showSelectedRow());
    }
    return KeyEventResult.handled;
  }

  void _showSelectedRow() {
    if (!mounted || !_scrollController.hasClients || _rowExtent == 0) return;
    final position = _scrollController.position;
    final top = (_selectedIndex ~/ 8) * _rowExtent;
    final bottom = top + _rowExtent;
    final offset = position.pixels;
    if (top < offset) {
      _scrollController.jumpTo(top.clamp(0.0, position.maxScrollExtent));
    } else if (bottom > offset + position.viewportDimension) {
      _scrollController.jumpTo(
        (bottom - position.viewportDimension).clamp(
          0.0,
          position.maxScrollExtent,
        ),
      );
    }
  }

  // Keep the existing emoji order for mouse and keyboard selection.
  static const _emojis = [
    '😀',
    '😃',
    '😄',
    '😁',
    '😅',
    '😂',
    '🤣',
    '😊',
    '😇',
    '🙂',
    '😉',
    '😍',
    '🥰',
    '😘',
    '😗',
    '😋',
    '😛',
    '😜',
    '🤪',
    '😝',
    '🤑',
    '🤗',
    '🤭',
    '🤫',
    '🤔',
    '😐',
    '😑',
    '😶',
    '😏',
    '😒',
    '🙄',
    '😬',
    '😮',
    '😯',
    '😲',
    '😳',
    '🥺',
    '😢',
    '😭',
    '😤',
    '👍',
    '👎',
    '👌',
    '✌️',
    '🤞',
    '🤟',
    '🤙',
    '👏',
    '🙌',
    '🤝',
    '🙏',
    '💪',
    '🫡',
    '🫶',
    '👀',
    '🧠',
    '❤️',
    '🧡',
    '💛',
    '💚',
    '💙',
    '💜',
    '🖤',
    '🤍',
    '🔥',
    '✨',
    '🎉',
    '🎊',
    '💯',
    '💥',
    '💫',
    '🚀',
    '💻',
    '📱',
    '💼',
    '📎',
    '📌',
    '🗂️',
    '✅',
    '❌',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final recent = ref.watch(recentEmojisProvider);

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onFocusChange: (focused) {
        if (mounted) setState(() => _hasFocus = focused);
      },
      onKeyEvent: _onKeyEvent,
      child: Container(
        width: 340,
        constraints: const BoxConstraints(maxHeight: 280),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.divider),
          boxShadow: [
            BoxShadow(
              color: colors.textPrimary.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
              child: Row(
                children: [
                  Text(
                    'Emoji',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: widget.onClose,
                    icon: Icon(Icons.close, size: 16, color: colors.textHint),
                    tooltip: 'Close',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.divider),
            if (recent.isNotEmpty) ...[
              _RecentEmojiRow(emojis: recent, onSelected: _select),
              Divider(height: 1, color: colors.divider),
            ],
            Flexible(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _rowExtent = (constraints.maxWidth - 16 - 7 * 4) / 8 + 4;
                  return GridView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    shrinkWrap: true,
                    itemCount: _emojis.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 8,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                        ),
                    itemBuilder: (context, index) {
                      final isSelected = _hasFocus && index == _selectedIndex;
                      return Semantics(
                        label: _emojis[index],
                        button: true,
                        selected: isSelected,
                        excludeSemantics: true,
                        onTap: () => _select(_emojis[index]),
                        child: InkWell(
                          onTap: () => _select(_emojis[index]),
                          canRequestFocus: false,
                          borderRadius: BorderRadius.circular(6),
                          hoverColor: colors.onPrimary.withValues(alpha: 0.08),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: isSelected
                                  ? Border.all(color: colors.primary, width: 2)
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                _emojis[index],
                                style: const TextStyle(fontSize: 20),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The emojis picked most recently this session, newest first (Ziki #3433).
class _RecentEmojiRow extends StatelessWidget {
  const _RecentEmojiRow({required this.emojis, required this.onSelected});

  final List<String> emojis;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text(
              'Recently used',
              style: TextStyle(
                color: colors.textHint,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Row(
            children: [
              for (final emoji in emojis)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Tooltip(
                    message: 'Recently used $emoji',
                    excludeFromSemantics: true,
                    child: Semantics(
                      // Its own node, so it isn't merged into the picker's.
                      container: true,
                      label: 'Recently used $emoji',
                      button: true,
                      excludeSemantics: true,
                      onTap: () => onSelected(emoji),
                      child: InkWell(
                        key: ValueKey('recent-emoji-$emoji'),
                        onTap: () => onSelected(emoji),
                        canRequestFocus: false,
                        borderRadius: BorderRadius.circular(6),
                        hoverColor: colors.onPrimary.withValues(alpha: 0.08),
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: Center(
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
