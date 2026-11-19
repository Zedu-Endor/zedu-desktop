import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';
import '../../fakes/buzz_call_fakes.dart';

void main() {
  group('Incoming call ringtone (Ziki #2441)', () {
    late FakeRingtone ringtone;
    late ProviderContainer container;

    setUp(() {
      ringtone = FakeRingtone();
      container = ProviderContainer(
        overrides: [
          callRingtoneProvider.overrideWithValue(ringtone),
          buzzRepositoryProvider.overrideWithValue(FakeBuzzCallRepository()),
          buzzCallServiceProvider.overrideWithValue(FakeBuzzCallService()),
          callSignalingProvider.overrideWithValue(FakeCallSignaling()),
          authNotifierProvider.overrideWith(FakeSignedInAuthNotifier.new),
        ],
      );
      addTearDown(container.dispose);
    });

    ActiveCallNotifier calls() => container.read(activeCallProvider);

    void ring() => calls().receiveIncomingCall(
      buzzId: 'buzz-1',
      remoteUserId: 'u-1',
      remoteUserName: 'Ada',
      channelId: 'c-1',
    );

    test('an incoming call starts the ringtone once', () {
      ring();
      calls().setFullPage(true); // another update while still ringing

      expect(ringtone.calls, ['start']);
    });

    test('accepting the call stops the ringtone', () async {
      ring();
      await calls().acceptCall();

      expect(calls().state.status, CallStatus.connecting);
      expect(ringtone.calls, ['start', 'stop']);
    });

    test('declining the call stops the ringtone', () async {
      ring();
      await calls().declineCall();

      expect(calls().state.status, CallStatus.ended);
      expect(ringtone.calls, ['start', 'stop']);
    });

    test('the call ending (caller hung up or timed out) stops it', () async {
      ring();
      await calls().endCall();

      expect(ringtone.calls, ['start', 'stop']);
    });

    test('no ringtone while notifications are paused', () {
      container
          .read(notificationSettingsProvider.notifier)
          .setDndMode(const Duration(hours: 1));

      ring();

      expect(calls().state.status, CallStatus.incoming);
      expect(ringtone.calls, isEmpty);
    });

    test('an outgoing call does not ring', () async {
      await calls().initiateCall(
        remoteUserId: 'u-1',
        remoteUserName: 'Ada',
        channelId: 'c-1',
      );

      expect(calls().state.status, CallStatus.calling);
      expect(ringtone.calls, isEmpty);
    });

    test('the ringtone asset is bundled', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final data = await rootBundle.load('assets/${AudioCallRingtone.asset}');
      expect(data.lengthInBytes, greaterThan(1000));
    });
  });
}
