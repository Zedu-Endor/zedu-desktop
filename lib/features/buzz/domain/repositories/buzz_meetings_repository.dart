import 'package:zedu/core/core.dart';

abstract class BuzzMeetingsRepository {
  /// Creates a Buzz meeting in the signed-in user's current organisation and
  /// returns its code.
  Future<Result<String>> createMeeting();
}

/// The meeting code in what someone typed: a bare code, or the last part of
/// a meeting link such as `https://zedu.chat/acme/buzz/abc-defg-hij`.
/// Empty when there is nothing usable.
String buzzMeetingCode(String input) {
  var text = input.trim();
  final cut = text.indexOf(RegExp('[?#]'));
  if (cut != -1) text = text.substring(0, cut);
  final parts = text.split('/').where((p) => p.trim().isNotEmpty).toList();
  return parts.isEmpty ? '' : parts.last.trim();
}

/// The web app's page for meeting [code] in [orgSlug], as the web app's
/// `getBuzzDetailsPath` builds it. [directJoin] skips the green room.
Uri buzzMeetingUrl({
  required String webBaseUrl,
  required String orgSlug,
  required String code,
  bool directJoin = false,
}) {
  final base = Uri.parse(webBaseUrl);
  return base.replace(
    pathSegments: [
      ...base.pathSegments.where((s) => s.isNotEmpty),
      orgSlug,
      'buzz',
      code,
    ],
    queryParameters: directJoin ? {'direct': '1'} : null,
  );
}
