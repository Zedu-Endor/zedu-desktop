import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../helpers/helpers.dart';

class _MockApi extends Mock implements ApiBaseService {}

ApiResponseModel<Map<String, dynamic>> _ok(Map<String, dynamic> data) =>
    ApiResponseModel(data: {'data': data}, statusCode: 200);

const _agora = {
  'token': 'rtc-token',
  'app_id': 'app-id',
  'channel_name': 'buzz-1',
  'uid': 'user-1',
};

void main() {
  late _MockApi api;
  late BuzzCallRepository repo;

  void stubPost(String path, Map<String, dynamic> response, {Object? data}) {
    when(
      () => api.post<Map<String, dynamic>>(
        path: path,
        data: data ?? any(named: 'data'),
      ),
    ).thenAnswer((_) async => _ok(response));
  }

  setUp(() {
    api = _MockApi();
    repo = BuzzCallRepositoryImpl(
      remoteDataSource: BuzzRemoteDataSourceImpl(apiBaseService: api),
    );
  });

  test('startDirectCall posts the DM channel and reads the call', () async {
    stubPost(
      '/buzz/direct-call',
      {
        'buzz_id': 'buzz-1',
        'buzz_code': 'CODE1',
        'caller_id': 'user-1',
        'caller_name': 'Ada',
        'participants': [
          {'user_id': 'user-2', 'username': 'Bob', 'join_status': 'pending'},
        ],
      },
      data: {'channel_id': 'dm-1'},
    );

    final result = await repo.startDirectCall('dm-1');

    final call = (result as Success<DirectCall>).value;
    expect(call.buzzId, 'buzz-1');
    expect(call.joinId, 'CODE1');
    expect(call.participants.single.username, 'Bob');
  });

  test(
    'startDirectCall without an id fails instead of joining nothing',
    () async {
      stubPost('/buzz/direct-call', {'status': 'ringing'});

      final result = await repo.startDirectCall('dm-1');

      expect(result, isA<Failure<DirectCall>>());
    },
  );

  test('join reads the session and its Agora credentials', () async {
    stubPost('/buzz/CODE1/join', {
      'buzz_id': 'buzz-1',
      'buzz_code': 'CODE1',
      'host_id': 'user-1',
      'participants': [
        {
          'user_id': 'user-2',
          'username': 'Bob',
          'avatar_url': '',
          'default_avatar_url': 'https://img/default.png',
        },
      ],
      'agora_token': _agora,
    });

    final session = (await repo.join('CODE1') as Success<BuzzSession>).value;

    expect(session.buzzId, 'buzz-1');
    expect(session.hostId, 'user-1');
    expect(session.agora.appId, 'app-id');
    expect(session.agora.token, 'rtc-token');
    expect(session.agora.uid, 'user-1');
    expect(
      session.participants.single.effectiveAvatarUrl,
      'https://img/default.png',
    );
  });

  test('join without an App ID fails rather than starting media', () async {
    stubPost('/buzz/CODE1/join', {
      'buzz_id': 'buzz-1',
      'agora_token': {'token': 't', 'uid': 'user-1'},
    });

    expect(await repo.join('CODE1'), isA<Failure<BuzzSession>>());
  });

  test('respond sends the action as the backend expects', () async {
    for (final action in BuzzCallResponse.values) {
      stubPost(
        '/buzz/buzz-1/respond',
        {'buzz_id': 'buzz-1', 'buzz_code': 'CODE1'},
        data: {'action': action.apiValue},
      );
      final result = await repo.respond('buzz-1', action);
      expect(result, isA<Success<DirectCall>>(), reason: action.name);
    }
    expect(BuzzCallResponse.values.map((a) => a.apiValue), [
      'accept',
      'decline',
      'timeout',
      'cancel',
    ]);
  });

  test('token asks for the screen-share account', () async {
    stubPost(
      '/buzz/token',
      {
        'token': 'screen-token',
        'uid': 'screen-user-1',
        'app_id': 'app-id',
        'channel_name': 'screen-buzz-1',
      },
      data: {'buzz_id': 'buzz-1', 'uid': 'screen-user-1'},
    );

    final credentials =
        (await repo.token(
                  buzzId: 'buzz-1',
                  uid: buzzScreenShareAccount('user-1'),
                )
                as Success<BuzzAgoraCredentials>)
            .value;

    expect(credentials.token, 'screen-token');
    expect(credentials.channelName, 'screen-buzz-1');
  });

  test('token without a token fails', () async {
    stubPost('/buzz/token', {'uid': 'screen-user-1'});

    final result = await repo.token(buzzId: 'buzz-1', uid: 'screen-user-1');

    expect(result, isA<Failure<BuzzAgoraCredentials>>());
  });

  test('leave, end, reactions and mute hit their endpoints', () async {
    when(
      () => api.post<Map<String, dynamic>>(
        path: any(named: 'path'),
        data: any(named: 'data'),
      ),
    ).thenAnswer((_) async => _ok(const {}));

    expect(await repo.leave('buzz-1'), isA<Success<void>>());
    expect(await repo.end('buzz-1'), isA<Success<void>>());
    expect(await repo.sendReaction('buzz-1', '🎉'), isA<Success<void>>());
    expect(await repo.muteParticipants('buzz-1'), isA<Success<void>>());

    verify(
      () => api.post<Map<String, dynamic>>(path: '/buzz/buzz-1/leave'),
    ).called(1);
    verify(
      () => api.post<Map<String, dynamic>>(
        path: '/buzz/buzz-1/end',
        data: const <String, dynamic>{},
      ),
    ).called(1);
    verify(
      () => api.post<Map<String, dynamic>>(
        path: '/buzz/buzz-1/reaction',
        data: {'reaction_type': 'emoji', 'content': '🎉'},
      ),
    ).called(1);
    verify(
      () => api.post<Map<String, dynamic>>(
        path: '/buzz/buzz-1/mute-participants',
        data: const <String, dynamic>{},
      ),
    ).called(1);
  });

  test('metadata returns the raw data object', () async {
    when(
      () => api.get<Map<String, dynamic>>(path: '/buzz/buzz-1/metadata'),
    ).thenAnswer((_) async => _ok({'buzz_id': 'buzz-1', 'status': 'active'}));

    final data =
        (await repo.metadata('buzz-1') as Success<Map<String, dynamic>>).value;

    expect(data['status'], 'active');
  });

  test('an API error becomes a Failure with the same error', () async {
    const failure = ApiFailure(
      message: 'Forbidden',
      kind: ApiFailureKind.client,
    );
    when(
      () => api.post<Map<String, dynamic>>(
        path: any(named: 'path'),
        data: any(named: 'data'),
      ),
    ).thenThrow(failure);

    final result = await repo.end('buzz-1');

    expect((result as Failure<void>).error, same(failure));
  });

  test('a non-API error is wrapped as a Failure', () async {
    when(
      () => api.post<Map<String, dynamic>>(
        path: any(named: 'path'),
        data: any(named: 'data'),
      ),
    ).thenThrow(StateError('socket closed'));

    final result = await repo.leave('buzz-1');

    expect(result, isA<Failure<void>>());
  });
}
