import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Which Buzz action is running, if any.
enum BuzzMeetingAction { none, startNow, createForLater }

/// Creates meetings and builds their links for the Buzz page.
class BuzzMeetingsNotifier extends Notifier<BuzzMeetingAction> {
  @override
  BuzzMeetingAction build() => BuzzMeetingAction.none;

  String get _orgSlug => ref.read(buzzOrgSlugProvider);

  /// The link to meeting [code], or null when the organisation is unknown.
  Uri? linkFor(String code, {bool directJoin = false}) {
    final slug = _orgSlug;
    if (slug.isEmpty || code.isEmpty) return null;
    return buzzMeetingUrl(
      webBaseUrl: ref.read(buzzConfigProvider).webBaseUrl,
      orgSlug: slug,
      code: code,
      directJoin: directJoin,
    );
  }

  /// Creates a meeting and returns its link, or a failure with a message
  /// for the person. [startNow] links straight into the meeting.
  Future<Result<Uri>> create({required bool startNow}) async {
    if (state != BuzzMeetingAction.none) {
      return const Failure(ApiFailure(message: 'Already creating a meeting.'));
    }
    if (_orgSlug.isEmpty) {
      return const Failure(
        ApiFailure(message: 'Sign in again to start a meeting.'),
      );
    }
    state = startNow
        ? BuzzMeetingAction.startNow
        : BuzzMeetingAction.createForLater;
    try {
      final result = await ref
          .read(buzzMeetingsRepositoryProvider)
          .createMeeting();
      return switch (result) {
        Success<String>(:final value) => Success(
          linkFor(value, directJoin: startNow)!,
        ),
        Failure<String>() => const Failure(
          ApiFailure(message: 'Failed to create meeting. Please try again.'),
        ),
      };
    } finally {
      if (ref.mounted) state = BuzzMeetingAction.none;
    }
  }
}
