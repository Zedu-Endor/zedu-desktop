import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// The Buzz endpoints a direct call uses. Mirrors the web app's calls.
abstract class BuzzCallRepository {
  /// Starts a call in the DM [channelId] (`POST /buzz/direct-call`).
  Future<Result<DirectCall>> startDirectCall(String channelId);

  /// Joins a call and returns its Agora credentials (`POST /buzz/:id/join`).
  Future<Result<BuzzSession>> join(String buzzIdOrCode);

  /// Answers, declines, times out or cancels a call (`POST /buzz/:id/respond`).
  Future<Result<DirectCall>> respond(String buzzId, BuzzCallResponse action);

  /// Credentials for one Agora user account in a call (`POST /buzz/token`),
  /// used for the screen share's own `screen-<user id>` account.
  Future<Result<BuzzAgoraCredentials>> token({
    required String buzzId,
    required String uid,
  });

  /// Leaves the call; the others stay in it (`POST /buzz/:id/leave`).
  Future<Result<void>> leave(String buzzId);

  /// Ends the call for everyone (`POST /buzz/:id/end`).
  Future<Result<void>> end(String buzzId);

  /// Sends an emoji reaction to everyone in the call
  /// (`POST /buzz/:id/reaction`).
  Future<Result<void>> sendReaction(String buzzId, String emoji);

  /// Mutes everyone else in the call (`POST /buzz/:id/mute-participants`).
  Future<Result<void>> muteParticipants(String buzzId);

  /// The call's details as the server returns them (`GET /buzz/:id/metadata`).
  /// Left raw until a screen needs specific fields.
  Future<Result<Map<String, dynamic>>> metadata(String buzzId);
}
