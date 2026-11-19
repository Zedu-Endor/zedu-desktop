import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// "Share {file}": picks workspace members and sends them the file by direct
/// message, as the web app's share modal does. Returns how it went once the
/// file reached someone; when nothing was sent the dialog stays open with the
/// reason.
class ShareFileDialog extends ConsumerStatefulWidget {
  const ShareFileDialog({super.key, required this.file});

  final WorkspaceFile file;

  /// Members shown per search.
  static const maxSuggestions = 5;

  /// The longest note the share endpoint accepts.
  static const maxNoteLength = 500;

  static Future<FileShareOutcome?> show(
    BuildContext context, {
    required WorkspaceFile file,
  }) => showDialog<FileShareOutcome>(
    context: context,
    builder: (_) => ShareFileDialog(file: file),
  );

  @override
  ConsumerState<ShareFileDialog> createState() => _ShareFileDialogState();
}

class _ShareFileDialogState extends ConsumerState<ShareFileDialog> {
  final _search = TextEditingController();
  final _note = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;
  String _query = '';
  final _recipients = <OrgMember>[];
  var _permission = FileSharePermission.view;
  var _access = FileShareAccess.invited;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _note.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = text.trim());
    });
    if (_error != null) setState(() => _error = null);
  }

  /// Members who can still be added: not deactivated, not added yet, and not
  /// the signed-in user [selfId], who can't share a file with themselves.
  List<OrgMember> _suggestions(List<OrgMember> members, String? selfId) => [
    for (final m in members)
      if (!m.deactivated &&
          m.id != selfId &&
          !_recipients.any((r) => r.id == m.id))
        m,
  ].take(ShareFileDialog.maxSuggestions).toList();

  void _add(OrgMember member) {
    setState(() {
      _recipients.add(member);
      _error = null;
      _query = '';
    });
    _debounce?.cancel();
    _search.clear();
    _searchFocus.requestFocus();
  }

  void _remove(OrgMember member) =>
      setState(() => _recipients.removeWhere((r) => r.id == member.id));

  /// Enter adds the first match, or says why it can't.
  void _addFirstMatch(List<OrgMember> suggestions) {
    if (suggestions.isNotEmpty && _search.text.trim() == _query) {
      _add(suggestions.first);
    } else if (_search.text.trim().isNotEmpty && _query.length >= 2) {
      setState(
        () => _error =
            'No workspace member matches "${_search.text.trim()}". '
            'Only workspace members can receive shared files.',
      );
    }
  }

  Future<void> _send() async {
    if (_recipients.isEmpty) {
      setState(() => _error = 'Add at least one person.');
      return;
    }
    setState(() => _error = null);
    final outcome = await ref
        .read(fileSharesProvider.notifier)
        .share(
          widget.file,
          recipients: List.of(_recipients),
          permission: _permission,
          access: _access,
          note: _note.text,
        );
    if (!mounted) return;
    if (outcome.shared) {
      Navigator.of(context).pop(outcome);
    } else {
      setState(() => _error = outcome.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isSharing = ref.watch(
      fileSharesProvider.select((ids) => ids.contains(widget.file.id)),
    );
    final searching = _query.length >= 2;
    final results = searching ? ref.watch(peopleListProvider(_query)) : null;
    final selfId = ref.watch(authNotifierProvider.select((s) => s.user?.id));
    final suggestions = _suggestions(
      results?.value?.members ?? const [],
      selfId,
    );

    final labelStyle = context.textTheme.bodyMedium?.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: colors.textPrimary,
    );
    final bodyStyle = context.textTheme.bodyMedium?.copyWith(
      fontSize: 13,
      color: colors.textPrimary,
    );
    final hintStyle = bodyStyle?.copyWith(color: colors.textSecondary);
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: color),
    );
    InputDecoration decoration(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: hintStyle,
      isDense: true,
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: border(colors.divider),
      focusedBorder: border(colors.primary),
      disabledBorder: border(colors.divider),
    );

    Widget dropdown<T>({
      required T value,
      required List<T> values,
      required String Function(T) label,
      required ValueChanged<T> onChanged,
      IconData Function(T)? icon,
    }) => DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        isDense: true,
        borderRadius: BorderRadius.circular(6),
        dropdownColor: colors.onPrimary,
        style: bodyStyle,
        icon: Icon(Icons.expand_more, size: 18, color: colors.textSecondary),
        onChanged: isSharing
            ? null
            : (v) {
                if (v != null) onChanged(v);
              },
        items: [
          for (final v in values)
            DropdownMenuItem(
              value: v,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon(v), size: 16, color: colors.textSecondary),
                    const SizedBox(width: 8),
                  ],
                  Text(label(v)),
                ],
              ),
            ),
        ],
      ),
    );

    Widget suggestionList() {
      if (!searching) return const SizedBox.shrink();
      Widget note(String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(text, style: hintStyle),
      );
      final list = switch (results) {
        AsyncValue(hasValue: true) when suggestions.isNotEmpty => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final m in suggestions)
              InkWell(
                onTap: isSharing ? null : () => _add(m),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      MemberAvatar(member: m, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: bodyStyle,
                            ),
                            if (m.email.isNotEmpty)
                              Text(
                                m.email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: hintStyle?.copyWith(fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        AsyncValue(hasError: true) => note('Could not search members.'),
        AsyncValue(hasValue: true) => note('No workspace member matches.'),
        _ => note('Searching…'),
      };
      return Container(
        margin: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(
          color: colors.onPrimary,
          border: Border.all(color: colors.divider),
          borderRadius: BorderRadius.circular(6),
        ),
        child: list,
      );
    }

    return Dialog(
      backgroundColor: colors.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Share ${widget.file.name}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.titleMedium?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: Text('Add people', style: labelStyle)),
                  dropdown(
                    value: _permission,
                    values: FileSharePermission.values,
                    label: (p) => p.label,
                    icon: (p) => p == FileSharePermission.view
                        ? Icons.visibility_outlined
                        : Icons.edit_outlined,
                    onChanged: (p) => setState(() => _permission = p),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_recipients.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final r in _recipients)
                      InputChip(
                        label: Text(r.displayName, style: bodyStyle),
                        backgroundColor: colors.primaryBg,
                        side: BorderSide.none,
                        visualDensity: VisualDensity.compact,
                        deleteIconColor: colors.textSecondary,
                        deleteButtonTooltipMessage: 'Remove ${r.displayName}',
                        onDeleted: isSharing ? null : () => _remove(r),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              TextField(
                key: const ValueKey('share-people-field'),
                controller: _search,
                focusNode: _searchFocus,
                autofocus: true,
                enabled: !isSharing,
                style: bodyStyle,
                onChanged: _onSearchChanged,
                onSubmitted: (_) {
                  _addFirstMatch(suggestions);
                  _searchFocus.requestFocus();
                },
                decoration: decoration('Search workspace members by name'),
              ),
              suggestionList(),
              const SizedBox(height: 16),
              Text('Message', style: labelStyle),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('share-note-field'),
                controller: _note,
                enabled: !isSharing,
                minLines: 3,
                maxLines: 5,
                maxLength: ShareFileDialog.maxNoteLength,
                style: bodyStyle,
                decoration: decoration('Add additional notes'),
              ),
              const SizedBox(height: 16),
              Text('Access', style: labelStyle),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: dropdown(
                  value: _access,
                  values: FileShareAccess.values,
                  label: (a) => a.label,
                  icon: (a) => a == FileShareAccess.invited
                      ? Icons.lock_outline
                      : Icons.public,
                  onChanged: (a) => setState(() => _access = a),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: bodyStyle?.copyWith(color: colors.error)),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: isSharing
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                    ),
                    onPressed: isSharing || _recipients.isEmpty ? null : _send,
                    child: Text(isSharing ? 'Sending…' : 'Send'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
