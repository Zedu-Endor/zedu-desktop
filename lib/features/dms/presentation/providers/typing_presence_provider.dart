import 'dart:async';

import 'package:zedu/core/core.dart';

/// One person currently typing in a conversation.
class TypingUser {
  const TypingUser({required this.userId, required this.displayName});

  final String userId;
  final String displayName;
}

/// Who else is typing in one conversation, keyed by user id.
///
/// Mirrors the web composer's typing event: an entry expires 4 seconds after
/// the last keystroke. The realtime transport (Centrifugo) plugs into
/// [setTyping] when it lands.
class TypingPresenceNotifier extends Notifier<Map<String, TypingUser>> {
  TypingPresenceNotifier(this.channelId);

  final String channelId;

  /// How long a keystroke keeps someone listed, matching the web client.
  static const typingExpiry = Duration(seconds: 4);

  /// One expiry timer per typist, restarted on every keystroke.
  final Map<String, Timer> _expiryTimers = {};

  @override
  Map<String, TypingUser> build() {
    ref.onDispose(() {
      for (final timer in _expiryTimers.values) {
        timer.cancel();
      }
      _expiryTimers.clear();
    });
    return const {};
  }

  /// Records a keystroke from [userId], (re)starting their 4-second window.
  void setTyping({required String userId, required String displayName}) {
    if (userId.isEmpty || displayName.isEmpty) return;
    if (!ref.mounted) return;
    _expiryTimers[userId]?.cancel();
    _expiryTimers[userId] = Timer(typingExpiry, () => clearTyping(userId));
    state = {
      ...state,
      userId: TypingUser(userId: userId, displayName: displayName),
    };
  }

  /// Drops [userId] at once (message sent, box emptied, chat switched).
  void clearTyping(String userId) {
    _expiryTimers.remove(userId)?.cancel();
    if (!ref.mounted || !state.containsKey(userId)) return;
    state = {...state}..remove(userId);
  }
}

/// Typing presence per conversation, shared by channels and DMs.
final typingPresenceProvider = NotifierProvider.autoDispose
    .family<TypingPresenceNotifier, Map<String, TypingUser>, String>(
      TypingPresenceNotifier.new,
    );

/// One-line "X is typing..." text. Empty when nobody is typing.
String typingLabel(List<TypingUser> typists) {
  switch (typists.length) {
    case 0:
      return '';
    case 1:
      return '${typists.first.displayName} is typing...';
    case 2:
      return '${typists[0].displayName} and ${typists[1].displayName} are typing...';
    default:
      final extra = typists.length - 2;
      return '${typists[0].displayName}, ${typists[1].displayName} and '
          '$extra other${extra == 1 ? '' : 's'} are typing...';
  }
}

/// One-line typing indicator above the composer box. [excludeUserId] hides
/// one person (usually the current user); a plain value so the indicator
/// never depends on auth setup itself.
class TypingIndicator extends ConsumerWidget {
  const TypingIndicator({
    super.key,
    required this.channelId,
    this.excludeUserId,
  });

  final String channelId;
  final String? excludeUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presence = ref.watch(typingPresenceProvider(channelId));
    final others = presence.values
        .where((user) => user.userId != excludeUserId)
        .toList();
    if (others.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          typingLabel(others),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: context.colors.textHint,
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}
