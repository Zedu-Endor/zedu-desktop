import 'package:zedu/core/core.dart';

enum HomeSidebarType { home, dms, people, files, buzz }

class HomeSidebarNotifier extends Notifier<HomeSidebarType> {
  @override
  HomeSidebarType build() => HomeSidebarType.home;

  void setType(HomeSidebarType type) {
    state = type;
  }
}

final homeSidebarProvider =
    NotifierProvider<HomeSidebarNotifier, HomeSidebarType>(
      HomeSidebarNotifier.new,
    );

/// Whether the home sidebar (workspace, channels, DMs lists) is shown.
/// Hidden with the top-bar button or Cmd/Ctrl+\ (Ziki #2848); the choice
/// lasts for the session.
class HomeSidebarVisibleNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

final homeSidebarVisibleProvider =
    NotifierProvider<HomeSidebarVisibleNotifier, bool>(
      HomeSidebarVisibleNotifier.new,
    );
