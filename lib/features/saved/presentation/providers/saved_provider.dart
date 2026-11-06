import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// The ready-made reminder times offered on a message.
enum ReminderPreset {
  inThirtyMinutes,
  inOneHour,
  tomorrowMorning;

  String get label => switch (this) {
    ReminderPreset.inThirtyMinutes => 'In 30 minutes',
    ReminderPreset.inOneHour => 'In 1 hour',
    ReminderPreset.tomorrowMorning => 'Tomorrow at 9:00 AM',
  };

  /// Resolved against [now] rather than reading the clock directly, so the
  /// boundaries can be tested.
  DateTime resolve(DateTime now) => switch (this) {
    ReminderPreset.inThirtyMinutes => now.add(const Duration(minutes: 30)),
    ReminderPreset.inOneHour => now.add(const Duration(hours: 1)),
    ReminderPreset.tomorrowMorning => DateTime(
      now.year,
      now.month,
      now.day + 1,
      9,
    ),
  };
}

/// The saved list as the UI sees it.
class SavedState {
  const SavedState({
    this.items = const [],
    this.loading = false,
    this.error,
    this.loaded = false,
  });

  final List<SavedMessage> items;
  final bool loading;
  final Object? error;

  /// Whether the list has been fetched at least once. Distinguishes "nothing
  /// saved" from "not asked yet", so the empty state cannot be shown before
  /// the first load.
  final bool loaded;

  bool get isEmpty => loaded && items.isEmpty;

  SavedState copyWith({
    List<SavedMessage>? items,
    bool? loading,
    Object? error,
    bool clearError = false,
    bool? loaded,
  }) => SavedState(
    items: items ?? this.items,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
    loaded: loaded ?? this.loaded,
  );
}

/// The saved messages and their reminders.
///
/// This deliberately does **not** fetch in [build], and does not watch the
/// selected workspace. Every message menu asks whether its message is saved,
/// and making that question reach the workspace provider would give every
/// message bubble a hidden dependency on organisation loading and a network
/// call at startup. The list is fetched when something asks for it: opening
/// Saved, or saving, removing or reminding. The Saved view watches the
/// workspace and reloads when it changes.
class SavedNotifier extends Notifier<SavedState> {
  @override
  SavedState build() => const SavedState();

  String get _orgId => ref.read(currentOrgIdProvider);

  /// Overdue first, because those are the ones the user has already been
  /// notified about; everything else newest-saved first.
  static List<SavedMessage> sortForDisplay(List<SavedMessage> items) {
    final sorted = [...items];
    sorted.sort((a, b) {
      if (a.overdue != b.overdue) return a.overdue ? -1 : 1;
      return b.savedAt.compareTo(a.savedAt);
    });
    return sorted;
  }

  Future<void> refresh() async {
    final orgId = _orgId;
    if (orgId.isEmpty) {
      state = const SavedState(loaded: true);
      return;
    }

    state = state.copyWith(loading: true, clearError: true);
    try {
      final items = await ref.read(savedRepositoryProvider).list(orgId: orgId);
      state = SavedState(items: sortForDisplay(items), loaded: true);
    } catch (error) {
      state = state.copyWith(loading: false, error: error, loaded: true);
    }
  }

  /// Saves the message, then reloads so the new row carries the server's own
  /// id, which removing it later needs.
  Future<void> save(SavedTarget target) async {
    final orgId = _orgId;
    if (orgId.isEmpty) return;
    await ref.read(savedRepositoryProvider).save(orgId: orgId, target: target);
    await refresh();
  }

  Future<void> removeById(String savedMessageId) async {
    final orgId = _orgId;
    if (orgId.isEmpty) return;
    await ref
        .read(savedRepositoryProvider)
        .remove(orgId: orgId, savedMessageId: savedMessageId);
    await refresh();
  }

  /// Removes whatever saved item corresponds to [target].
  ///
  /// Removing needs the saved item's own id, which only the list carries, so
  /// the list is fetched first when it has not been.
  Future<void> removeTarget(SavedTarget target) async {
    if (!state.loaded) await refresh();
    final saved = savedFor(target);
    if (saved == null) return;
    await removeById(saved.id);
  }

  /// Sets a reminder, saving the message first when the server does not hold
  /// it yet: on the server a reminder belongs to a saved message, so the
  /// order matters.
  ///
  /// Nothing is swallowed. If either call fails the error reaches the caller,
  /// which reports it, rather than leaving a reminder the user believes is
  /// set.
  Future<void> setReminder({
    required SavedTarget target,
    required DateTime remindAt,
  }) async {
    final orgId = _orgId;
    if (orgId.isEmpty) return;

    if (!state.loaded) await refresh();

    final repository = ref.read(savedRepositoryProvider);
    if (savedFor(target) == null) {
      await repository.save(orgId: orgId, target: target);
    }
    await repository.setReminder(
      orgId: orgId,
      target: target,
      remindAt: remindAt,
    );
    await refresh();
  }

  /// The saved item for a message, or null when it is not saved.
  SavedMessage? savedFor(SavedTarget target) {
    for (final item in state.items) {
      if (item.target.key == target.key) return item;
    }
    return null;
  }
}

final savedProvider = NotifierProvider<SavedNotifier, SavedState>(
  SavedNotifier.new,
);

/// Which messages are saved, for the message menu's label.
///
/// Reading this never starts a fetch, so a message bubble costs nothing until
/// the user actually opens Saved or saves something.
final savedKeysProvider = Provider<Set<String>>((ref) {
  final items = ref.watch(savedProvider).items;
  return {for (final item in items) item.target.key};
});
