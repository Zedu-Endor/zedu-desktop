import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../helpers/helpers.dart';

class _Api extends Mock implements ApiBaseService {}

void main() {
  const payload = <String, dynamic>{
    'channels_id': 'channel-general',
    'name': 'general',
    'description': '',
    'organisation_id': 'workspace',
    'owner_id': 'owner',
    'is_private': false,
  };

  test(
    'fetch preserves the backend channels_id used for starring and navigation',
    () async {
      final api = _Api();
      when(
        () => api.get<Map<String, dynamic>>(
          path: '/organisations/workspace/channels',
        ),
      ).thenAnswer(
        (_) async => ApiResponseModel<Map<String, dynamic>>(
          data: {
            'data': [payload],
          },
          statusCode: 200,
        ),
      );
      final channels = await ChannelRemoteDataSourceImpl(
        apiBaseService: api,
      ).fetchChannels('workspace');
      expect(channels.single.id, 'channel-general');
      expect(channels.single.organisationId, 'workspace');
    },
  );

  test('create preserves the returned channels_id', () async {
    final api = _Api();
    when(
      () => api.post<Map<String, dynamic>>(
        path: '/channels',
        data: any(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => ApiResponseModel<Map<String, dynamic>>(
        data: {'data': payload},
        statusCode: 201,
      ),
    );
    final channel = await ChannelRemoteDataSourceImpl(apiBaseService: api)
        .createChannel(
          name: 'general',
          description: '',
          orgId: 'workspace',
          username: 'owner',
          isPrivate: false,
        );
    expect(channel.id, 'channel-general');
  });

  test('legacy id payloads and serialization retain channel identity', () {
    final channel = Channel.fromJson({
      ...payload,
      'channels_id': null,
      'id': 'legacy-id',
    });
    expect(channel.id, 'legacy-id');
    expect(Channel.fromJson(channel.toJson()).id, 'legacy-id');
  });
}
