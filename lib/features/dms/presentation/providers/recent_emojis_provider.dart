import 'package:zedu/core/core.dart';

/// The emojis picked in the emoji picker this session, newest first, for its
/// Recently used row (Ziki #3433). Kept in memory only.
class RecentEmojisNotifier extends Notifier<List<String>> {
  /// How many emojis the Recently used row holds.
  static const maxCount = 8;

  @override
  List<String> build() => const [];

  /// Moves [emoji] to the front, without duplicates, keeping at most
  /// [maxCount].
  void add(String emoji) {
    state = [
      emoji,
      ...state.where((e) => e != emoji),
    ].take(maxCount).toList(growable: false);
  }
}

final recentEmojisProvider =
    NotifierProvider<RecentEmojisNotifier, List<String>>(
      RecentEmojisNotifier.new,
    );
