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

/// Whether what someone typed is an address rather than a bare meeting code.
bool isBuzzMeetingAddress(String input) => input.trim().contains('/');

/// The meeting page for a pasted link, keeping the organisation in the link.
/// Null unless it's a `<org>/buzz/<code>` link on the web app at [webBaseUrl],
/// so a link from another service is never opened as a Zedu meeting.
Uri? buzzMeetingUrlFromLink(String input, {required String webBaseUrl}) {
  final text = input.trim();
  final uri = Uri.tryParse(text.contains('://') ? text : 'https://$text');
  final base = Uri.parse(webBaseUrl);
  if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
    return null;
  }
  String host(Uri u) =>
      u.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  if (host(uri) != host(base)) return null;

  final basePath = base.pathSegments.where((s) => s.isNotEmpty).toList();
  final path = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (path.length != basePath.length + 3) return null;
  for (var i = 0; i < basePath.length; i++) {
    if (path[i] != basePath[i]) return null;
  }
  final meeting = path.sublist(basePath.length);
  if (meeting[1] != 'buzz') return null;
  return buzzMeetingUrl(
    webBaseUrl: webBaseUrl,
    orgSlug: meeting[0],
    code: meeting[2],
    directJoin: uri.queryParameters['direct'] == '1',
  );
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
