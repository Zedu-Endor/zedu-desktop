import 'package:zedu/core/core.dart';

/// Whether the main sidebar (the workspace switcher and the channel/thread
/// lists) is showing. The rail on the far left stays visible either way, so
/// there is always a way back.
class SidebarVisibilityNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;

  void show() => state = true;

  void hide() => state = false;
}

final sidebarVisibilityProvider =
    NotifierProvider<SidebarVisibilityNotifier, bool>(
      SidebarVisibilityNotifier.new,
    );
