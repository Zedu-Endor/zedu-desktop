import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// The order the DM conversation list is drawn in. Defaults to the existing
/// recent-activity order; the choice lasts for the session.
class DmSortNotifier extends Notifier<DmSort> {
  @override
  DmSort build() => DmSort.recentActivity;

  void select(DmSort sort) => state = sort;
}

final dmSortProvider = NotifierProvider<DmSortNotifier, DmSort>(
  DmSortNotifier.new,
);
