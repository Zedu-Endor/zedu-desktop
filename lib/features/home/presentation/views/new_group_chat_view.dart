import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class NewGroupChatView extends ConsumerStatefulWidget {
  const NewGroupChatView({super.key});

  @override
  ConsumerState<NewGroupChatView> createState() => _NewGroupChatViewState();
}

class _NewGroupChatViewState extends ConsumerState<NewGroupChatView> {
  final TextEditingController _searchController = TextEditingController();
  late final FocusNode _focusNode = FocusNode(
    onKeyEvent: _handleSuggestionKeys,
  );
  final ScrollController _suggestionsScrollController = ScrollController();
  final List<TeamMember> _selectedMembers = [];
  bool _isLoading = false;
  String? _errorMessage;

  int _highlightedIndex = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _focusNode.dispose();
    _suggestionsScrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() => setState(() => _highlightedIndex = 0);

  List<_RecipientSuggestion> _suggestionsFor(
    UserProfileState profile,
    List<Channel> channels,
  ) {
    final rawQuery = _searchController.text.trim().toLowerCase();
    final peopleQuery = rawQuery.startsWith('@')
        ? rawQuery.substring(1)
        : rawQuery;
    final channelQuery = rawQuery.startsWith('#')
        ? rawQuery.substring(1)
        : rawQuery;
    final suggestions = <_RecipientSuggestion>[];
    for (final member in profile.teamMembers) {
      if (member.status != TeamMemberStatus.active ||
          _selectedMembers.any((selected) => selected.id == member.id)) {
        continue;
      }
      final name = (member.name ?? '').toLowerCase();
      final email = member.email.toLowerCase();
      if (peopleQuery.isEmpty ||
          name.contains(peopleQuery) ||
          email.contains(peopleQuery)) {
        suggestions.add(_RecipientSuggestion.person(member));
      }
    }
    for (final channel in channels) {
      if (channel.archived || channel.name.isEmpty) continue;
      final name = channel.name.toLowerCase();
      final description = '${channel.topic ?? ''} ${channel.description}'
          .toLowerCase();
      if (channelQuery.isEmpty ||
          name.contains(channelQuery) ||
          description.contains(channelQuery)) {
        suggestions.add(_RecipientSuggestion.channel(channel));
      }
    }
    return suggestions;
  }

  List<_RecipientSuggestion> _currentSuggestions() => _suggestionsFor(
    ref.read(userProfileNotifierProvider),
    ref.read(channelProvider).value ?? const <Channel>[],
  );

  KeyEventResult _handleSuggestionKeys(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final suggestions = _currentSuggestions();
    if (suggestions.isEmpty) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _selectHighlightedSuggestion();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _moveHighlight((_highlightedIndex + 1) % suggestions.length);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _moveHighlight(
        (_highlightedIndex - 1 + suggestions.length) % suggestions.length,
      );
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _moveHighlight(int index) {
    setState(() => _highlightedIndex = index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_suggestionsScrollController.hasClients) return;
      final position = _suggestionsScrollController.position;
      const itemExtent = 64.0;
      final itemTop = index * itemExtent;
      final itemBottom = itemTop + itemExtent;
      double? targetOffset;
      if (itemTop < position.pixels) {
        targetOffset = itemTop;
      } else if (itemBottom > position.pixels + position.viewportDimension) {
        targetOffset = itemBottom - position.viewportDimension;
      }
      if (targetOffset != null) {
        _suggestionsScrollController.jumpTo(
          targetOffset
              .clamp(position.minScrollExtent, position.maxScrollExtent)
              .toDouble(),
        );
      }
    });
  }

  void _selectHighlightedSuggestion() {
    final suggestions = _currentSuggestions();
    if (suggestions.isEmpty) return;
    _selectSuggestion(suggestions[_highlightedIndex % suggestions.length]);
  }

  void _selectSuggestion(_RecipientSuggestion suggestion) {
    final member = suggestion.member;
    if (member != null) {
      _toggleMemberSelection(member);
      return;
    }
    final channel = suggestion.channel!;
    FocusScope.of(context).unfocus();
    ref.read(selectedDmProvider.notifier).select(null);
    ref.read(activeChatProvider.notifier).selectChannel(channel.name);
  }

  void _toggleMemberSelection(TeamMember member) {
    setState(() {
      if (_selectedMembers.any((m) => m.id == member.id)) {
        _selectedMembers.removeWhere((m) => m.id == member.id);
      } else {
        _selectedMembers.add(member);
      }
      _highlightedIndex = 0;
    });
    _searchController.clear();
  }

  String _getMemberDisplayName(TeamMember member) {
    final name = member.name?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    final emailPrefix = member.email.split('@').first.trim();
    if (emailPrefix.isNotEmpty) {
      return emailPrefix;
    }
    return 'Member';
  }

  String _getMemberInitials(String displayName) {
    final clean = displayName.trim();
    if (clean.isEmpty) return '?';
    final runes = clean.runes.toList();
    if (runes.length > 1) {
      return String.fromCharCodes(runes.take(2)).toUpperCase();
    }
    return String.fromCharCode(runes.first).toUpperCase();
  }

  Future<void> _handleCreate() async {
    if (_selectedMembers.length < 2) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ref
        .read(groupDmProvider.notifier)
        .createGroupDm(_selectedMembers);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    switch (result) {
      case Success<GroupDM>():
        final newGroup = result.value;
        // Check if this was a duplicate group that already existed
        final selectedIds = _selectedMembers.map((m) => m.id).toSet();
        final groupIds = newGroup.members.map((m) => m.id).toSet();
        final isDuplicate =
            groupIds.length == selectedIds.length &&
            groupIds.containsAll(selectedIds);

        if (isDuplicate &&
            ref.read(groupDmProvider).any((g) => g.id == newGroup.id)) {
          // If the group DM was already in the sidebar list, we show a SnackBar and open it
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Opening existing conversation with ${newGroup.name}...',
                  ),
                ],
              ),
              backgroundColor: context.colors.primary,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Group DM "${newGroup.name}" created successfully!'),
                ],
              ),
              backgroundColor: context.colors.success,
            ),
          );
        }

        // Navigate to the newly created/existing Group DM!
        ref.read(activeChatProvider.notifier).selectGroupDm(newGroup.id);

      case Failure<GroupDM>():
        setState(() {
          _errorMessage = result.error.friendlyMessage;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final profileState = ref.watch(userProfileNotifierProvider);
    final channelState = ref.watch(channelProvider);
    final suggestions = _suggestionsFor(
      profileState,
      channelState.value ?? const <Channel>[],
    );

    return Container(
      color: colors.background,
      child: Stack(
        children: [
          Column(
            children: [
              // 1. Header
              _buildHeader(colors),

              // 2. Main Search and Chips Section
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Input container
                            _buildSearchInputContainer(colors),
                            const SizedBox(height: 12),

                            // Selected Member Chips
                            if (_selectedMembers.isNotEmpty) ...[
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _selectedMembers.map((member) {
                                  final name = _getMemberDisplayName(member);
                                  final initials = _getMemberInitials(name);
                                  return Chip(
                                    avatar: CircleAvatar(
                                      backgroundColor: colors.primary
                                          .withValues(alpha: 0.15),
                                      child: Text(
                                        initials,
                                        style: TextStyle(
                                          color: colors.primary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    label: Text(
                                      name,
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    deleteIcon: Icon(
                                      Icons.close,
                                      size: 14,
                                      color: colors.textHint,
                                    ),
                                    onDeleted: () =>
                                        _toggleMemberSelection(member),
                                    backgroundColor: colors.divider.withValues(
                                      alpha: 0.5,
                                    ),
                                    side: BorderSide.none,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Validation Helper Text
                            _buildValidationHelper(colors),

                            const SizedBox(
                              height: 120,
                            ), // Spacer so the suggestion box isn't clipped
                          ],
                        ),

                        Positioned(
                          top: 60,
                          left: 0,
                          right: 0,
                          child: _buildSuggestionPanel(
                            colors,
                            suggestions,
                            isLoading:
                                profileState.isLoading ||
                                channelState.isLoading,
                            hasError:
                                profileState.error != null ||
                                channelState.hasError,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Bottom Message Editor (Mock UI replicating home message editor)
              _buildBottomMessageEditor(colors),
            ],
          ),

          // 4. Loading/Saving Spinner Overlay
          if (_isLoading)
            Container(
              color: Colors.white.withValues(alpha: 0.7),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: colors.primary),
                    const SizedBox(height: 16),
                    Text(
                      'Creating private group conversation...',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 5. Error & Retry Full Overlay
          if (_errorMessage != null)
            Container(
              color: Colors.white.withValues(alpha: 0.95),
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 500),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                      color: colors.error.withValues(alpha: 0.3),
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: colors.textPrimary.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: colors.error),
                      const SizedBox(height: 16),
                      Text(
                        'Creation Failed',
                        style: TextStyle(
                          color: colors.error,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _errorMessage = null;
                              });
                            },
                            child: Text(
                              'Cancel',
                              style: TextStyle(color: colors.textHint),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _errorMessage = null;
                              });
                              _handleCreate();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(AppPalette colors) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Row(
        children: [
          Text(
            'New message',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildSearchInputContainer(AppPalette colors) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.divider, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            'To: ',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _selectHighlightedSuggestion(),
              decoration: InputDecoration(
                hintText: '#a-channel, @somebody, or somebody',
                hintStyle: TextStyle(color: colors.textHint),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              style: TextStyle(color: colors.textPrimary, fontSize: 15),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _selectedMembers.length >= 2 ? _handleCreate : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: colors.divider,
              disabledForegroundColor: colors.textHint,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionPanel(
    AppPalette colors,
    List<_RecipientSuggestion> suggestions, {
    required bool isLoading,
    required bool hasError,
  }) {
    final query = _searchController.text.trim();
    String? emptyMessage;
    if (suggestions.isEmpty) {
      if (isLoading) {
        emptyMessage = 'Loading people and channels…';
      } else if (hasError) {
        emptyMessage = 'Could not load recipients. Try again later.';
      } else if (query.isNotEmpty) {
        emptyMessage = 'No people or channels match “$query”.';
      } else {
        emptyMessage = 'No people or channels are available in this workspace.';
      }
    }

    return Material(
      elevation: 8,
      shadowColor: colors.textPrimary.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 250),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.divider),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading && suggestions.isNotEmpty)
              const LinearProgressIndicator(minHeight: 2),
            if (emptyMessage != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    emptyMessage,
                    style: TextStyle(color: colors.textHint, fontSize: 13),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  controller: _suggestionsScrollController,
                  itemExtent: 64,
                  shrinkWrap: true,
                  itemCount: suggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = suggestions[index];
                    final highlighted = index == _highlightedIndex;
                    return Semantics(
                      container: true,
                      button: true,
                      selected: highlighted,
                      label: suggestion.accessibleLabel,
                      onTap: () => _selectSuggestion(suggestion),
                      child: InkWell(
                        excludeFromSemantics: true,
                        onTap: () => _selectSuggestion(suggestion),
                        child: ExcludeSemantics(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: highlighted
                                  ? colors.primary.withValues(alpha: 0.08)
                                  : null,
                              border: Border(
                                bottom: BorderSide(
                                  color: colors.divider,
                                  width: 0.5,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: colors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  child: Icon(
                                    suggestion.isPerson
                                        ? Icons.person_outline
                                        : Icons.tag,
                                    size: 17,
                                    color: colors.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        suggestion.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: colors.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        suggestion.subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: colors.textHint,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  suggestion.isPerson
                                      ? Icons.add_circle_outline
                                      : Icons.arrow_forward,
                                  color: colors.primary,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildValidationHelper(AppPalette colors) {
    final count = _selectedMembers.length;
    final isReady = count >= 2;

    return Row(
      children: [
        Icon(
          isReady ? Icons.check_circle : Icons.info_outline,
          size: 16,
          color: isReady ? colors.success : colors.error,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            isReady
                ? 'Ready to create conversation! (Selected: $count members)'
                : 'Select at least 2 members to start a group DM (Selected: $count/2)',
            style: TextStyle(
              color: isReady ? colors.success : colors.error,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomMessageEditor(AppPalette colors) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      decoration: const BoxDecoration(color: Colors.white),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: colors.divider),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.format_bold, size: 20, color: colors.textHint),
                const SizedBox(width: 16),
                Icon(Icons.format_italic, size: 20, color: colors.textHint),
                const SizedBox(width: 16),
                Icon(Icons.link, size: 20, color: colors.textHint),
                const SizedBox(width: 16),
                Icon(Icons.list, size: 20, color: colors.textHint),
                const SizedBox(width: 16),
                Icon(Icons.code, size: 20, color: colors.textHint),
              ],
            ),
            Divider(height: 24, color: colors.divider),
            const TextField(
              enabled: false, // Disabled during creation screen
              decoration: InputDecoration(
                hintText: 'Message Ruby - Social Media Handler',
                border: InputBorder.none,
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.add, color: colors.textHint.withValues(alpha: 0.75)),
                const SizedBox(width: 12),
                Icon(
                  Icons.emoji_emotions_outlined,
                  color: colors.textHint.withValues(alpha: 0.75),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.alternate_email,
                  color: colors.textHint.withValues(alpha: 0.75),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.videocam_outlined,
                  color: colors.textHint.withValues(alpha: 0.75),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.mic_none_outlined,
                  color: colors.textHint.withValues(alpha: 0.75),
                ),
                const Spacer(),
                Icon(
                  Icons.send_rounded,
                  color: colors.textHint.withValues(alpha: 0.5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipientSuggestion {
  const _RecipientSuggestion.person(this.member) : channel = null;

  const _RecipientSuggestion.channel(this.channel) : member = null;

  final TeamMember? member;
  final Channel? channel;

  bool get isPerson => member != null;

  String get title {
    if (!isPerson) return '#${channel!.name}';
    final name = member!.name?.trim();
    if (name != null && name.isNotEmpty) return name;
    final emailPrefix = member!.email.split('@').first.trim();
    return emailPrefix.isNotEmpty ? emailPrefix : 'Member';
  }

  String get subtitle => isPerson
      ? member!.email
      : (channel!.topic?.isNotEmpty == true
            ? channel!.topic!
            : channel!.description);

  String get accessibleLabel => isPerson
      ? 'Add $title, ${member!.email}'
      : 'Open channel ${channel!.name}';
}
