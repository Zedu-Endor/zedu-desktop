/// Realtime call signals from the server (Centrifugo `direct_call_*` events on
/// the user's `<org id>/<user id>` channel). Kept behind an interface so the
/// Centrifugo client plugs in without touching the call state.
sealed class CallSignal {
  const CallSignal({required this.buzzId});

  final String buzzId;
}

/// `direct_call_initiated`: someone is calling this user.
class IncomingCallSignal extends CallSignal {
  const IncomingCallSignal({
    required super.buzzId,
    required this.callerId,
    required this.callerName,
    required this.channelId,
    this.avatarUrl = '',
  });

  final String callerId;
  final String callerName;
  final String channelId;
  final String avatarUrl;
}

/// `direct_call_response`: the person called accepted, declined or let it
/// time out. [joinStatus] is the server's value (`accept`, `decline`, ...).
class CallResponseSignal extends CallSignal {
  const CallResponseSignal({required super.buzzId, required this.joinStatus});

  final String joinStatus;

  bool get isAccepted => joinStatus == 'accept' || joinStatus == 'accepted';
  bool get isDeclined => joinStatus == 'decline' || joinStatus == 'declined';
  bool get isTimedOut => joinStatus == 'timeout';
}

/// `direct_call_canceled`: the caller stopped ringing.
class CallCanceledSignal extends CallSignal {
  const CallCanceledSignal({required super.buzzId});
}

/// Where call signals come from.
abstract class CallSignaling {
  Stream<CallSignal> get signals;

  Future<void> dispose();
}

/// Used until the realtime client is approved: there are no signals, so
/// outgoing calls rely on Agora's join and leave events instead.
class NoCallSignaling implements CallSignaling {
  const NoCallSignaling();

  @override
  Stream<CallSignal> get signals => const Stream.empty();

  @override
  Future<void> dispose() async {}
}
