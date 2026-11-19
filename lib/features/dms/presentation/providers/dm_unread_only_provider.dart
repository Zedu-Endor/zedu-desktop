import 'package:zedu/core/core.dart';

/// Whether the DM sidebar lists only conversations with unread messages.
/// Session-scoped, like the sort order.
class DmUnreadOnlyNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;

  void setEnabled(bool enabled) => state = enabled;
}

final dmUnreadOnlyProvider = NotifierProvider<DmUnreadOnlyNotifier, bool>(
  DmUnreadOnlyNotifier.new,
);
