/// How long an unanswered call rings before it counts as missed, on both the
/// caller's and the callee's side. Matches the web app's incoming call popup.
const Duration kBuzzRingTimeout = Duration(seconds: 60);

/// The reactions the web app sends in a call, in the order it shows them.
const List<String> kBuzzQuickReactions = [
  '❤️',
  '👍',
  '🎉',
  '👏',
  '😂',
  '😮',
  '😢',
  '🤔',
  '👎',
];

/// The Agora user account a participant shares their screen with. The backend
/// issues screen tokens for `screen-<user id>`, like the web app.
String buzzScreenShareAccount(String userId) => 'screen-$userId';

/// The Agora channel screen shares are published to: a separate channel from
/// the call's own (`buzz_id`), which every participant joins to watch shares.
String buzzScreenShareChannel(String buzzId) => 'screen-$buzzId';

/// Whether an Agora user account belongs to a screen share.
bool isBuzzScreenShareAccount(String account) => account.startsWith('screen-');

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value == null ? '' : value.toString();
}

List<BuzzCallParticipant> _participants(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map<dynamic, dynamic>>()
      .map((e) => BuzzCallParticipant.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

/// What Agora needs to join a channel, as `POST /buzz/token` and the
/// `agora_token` of a join return it.
class BuzzAgoraCredentials {
  const BuzzAgoraCredentials({
    required this.token,
    required this.appId,
    required this.channelName,
    required this.uid,
  });

  factory BuzzAgoraCredentials.fromJson(Map<String, dynamic> json) {
    return BuzzAgoraCredentials(
      token: _string(json, 'token'),
      appId: _string(json, 'app_id'),
      channelName: _string(json, 'channel_name'),
      uid: _string(json, 'uid'),
    );
  }

  final String token;
  final String appId;
  final String channelName;

  /// The Agora user account (a user id, or `screen-<user id>`).
  final String uid;

  bool get isComplete => token.isNotEmpty && uid.isNotEmpty;
}

/// A person in a call, as the Buzz endpoints describe them.
class BuzzCallParticipant {
  const BuzzCallParticipant({
    required this.userId,
    this.username = '',
    this.avatarUrl = '',
    this.defaultAvatarUrl = '',
    this.joinStatus = '',
    this.callRole = '',
  });

  factory BuzzCallParticipant.fromJson(Map<String, dynamic> json) {
    return BuzzCallParticipant(
      userId: _string(json, 'user_id'),
      username: _string(json, 'username'),
      avatarUrl: _string(json, 'avatar_url'),
      defaultAvatarUrl: _string(json, 'default_avatar_url'),
      joinStatus: _string(json, 'join_status'),
      callRole: _string(json, 'call_role'),
    );
  }

  final String userId;
  final String username;
  final String avatarUrl;
  final String defaultAvatarUrl;
  final String joinStatus;
  final String callRole;

  String get effectiveAvatarUrl =>
      avatarUrl.isNotEmpty ? avatarUrl : defaultAvatarUrl;
}

/// A direct call, as `POST /buzz/direct-call` and `POST /buzz/:id/respond`
/// return it.
class DirectCall {
  const DirectCall({
    required this.buzzId,
    required this.buzzCode,
    this.channelId = '',
    this.callerId = '',
    this.callerName = '',
    this.status = '',
    this.joinStatus = '',
    this.participants = const [],
  });

  factory DirectCall.fromJson(Map<String, dynamic> json) {
    return DirectCall(
      buzzId: _string(json, 'buzz_id'),
      buzzCode: _string(json, 'buzz_code'),
      channelId: _string(json, 'channel_id'),
      callerId: _string(json, 'caller_id'),
      callerName: _string(json, 'caller_name'),
      status: _string(json, 'status'),
      joinStatus: _string(json, 'join_status'),
      participants: _participants(json['participants']),
    );
  }

  final String buzzId;

  /// What the web app passes to `POST /buzz/:id/join`.
  final String buzzCode;
  final String channelId;
  final String callerId;
  final String callerName;
  final String status;
  final String joinStatus;
  final List<BuzzCallParticipant> participants;

  /// The id to join with: the code, as the web app does, else the id.
  String get joinId => buzzCode.isNotEmpty ? buzzCode : buzzId;
}

/// The call after joining it, as `POST /buzz/:id/join` returns it.
class BuzzSession {
  const BuzzSession({
    required this.buzzId,
    required this.agora,
    this.buzzCode = '',
    this.hostId = '',
    this.channelId = '',
    this.userId = '',
    this.status = '',
    this.participants = const [],
  });

  factory BuzzSession.fromJson(Map<String, dynamic> json) {
    final agora = json['agora_token'];
    return BuzzSession(
      buzzId: _string(json, 'buzz_id'),
      buzzCode: _string(json, 'buzz_code'),
      hostId: _string(json, 'host_id'),
      channelId: _string(json, 'channel_id'),
      userId: _string(json, 'user_id'),
      status: _string(json, 'status'),
      participants: _participants(json['participants']),
      agora: agora is Map
          ? BuzzAgoraCredentials.fromJson(Map<String, dynamic>.from(agora))
          : const BuzzAgoraCredentials(
              token: '',
              appId: '',
              channelName: '',
              uid: '',
            ),
    );
  }

  final String buzzId;
  final String buzzCode;
  final String hostId;
  final String channelId;
  final String userId;
  final String status;
  final List<BuzzCallParticipant> participants;
  final BuzzAgoraCredentials agora;
}

/// The `action` values `POST /buzz/:id/respond` accepts.
enum BuzzCallResponse {
  accept('accept'),
  decline('decline'),
  timeout('timeout'),

  /// The caller stops ringing before anyone answers.
  cancel('cancel');

  const BuzzCallResponse(this.apiValue);

  final String apiValue;
}
