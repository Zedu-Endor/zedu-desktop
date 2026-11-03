import '../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';

void main() {
  group('SecureStorageService access token', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));

    test('a remembered token is saved to storage', () async {
      final service = SecureStorageService();

      await service.saveAccessToken('token-1');

      expect(await service.getAccessToken(), 'token-1');
      // A new service reads the same storage, like the next app launch.
      expect(await SecureStorageService().getAccessToken(), 'token-1');
    });

    test('a token that is not remembered lasts for this run only', () async {
      final service = SecureStorageService();

      await service.saveAccessToken('token-1', persist: false);

      expect(await service.getAccessToken(), 'token-1');
      expect(await SecureStorageService().getAccessToken(), isNull);
    });

    test('not remembering replaces a token saved earlier', () async {
      final service = SecureStorageService();
      await service.saveAccessToken('old-token');

      await service.saveAccessToken('new-token', persist: false);

      expect(await service.getAccessToken(), 'new-token');
      expect(await SecureStorageService().getAccessToken(), isNull);
    });

    test('deleting clears the in-memory token too', () async {
      final service = SecureStorageService();
      await service.saveAccessToken('token-1', persist: false);

      await service.deleteAccessToken();

      expect(await service.getAccessToken(), isNull);
    });

    test('deletes only values matching a prefix', () async {
      FlutterSecureStorage.setMockInitialValues({
        'dm_draft_user-1_org-1_channel-1': 'draft-1',
        'dm_draft_user-1_org-2_channel-2': 'draft-2',
        'dm_draft_user-2_org-1_channel-1': 'other-user-draft',
        'unrelated': 'keep',
      });
      final service = SecureStorageService();

      await service.deleteValuesWithPrefix('dm_draft_user-1_');

      expect(await service.readData('dm_draft_user-1_org-1_channel-1'), isNull);
      expect(await service.readData('dm_draft_user-1_org-2_channel-2'), isNull);
      expect(
        await service.readData('dm_draft_user-2_org-1_channel-1'),
        'other-user-draft',
      );
      expect(await service.readData('unrelated'), 'keep');
    });

    test(
      'blocks new writes to a deleted user prefix until they sign in',
      () async {
        final service = SecureStorageService();
        const prefix = 'dm_draft_user-1_';

        await service.deleteValuesWithPrefix(prefix);
        await service.writeData('${prefix}org-1_channel-1', 'late draft');

        expect(await service.readData('${prefix}org-1_channel-1'), isNull);

        service.allowWritesWithPrefix(prefix);
        await service.writeData(
          '${prefix}org-1_channel-1',
          'new session draft',
        );

        expect(
          await service.readData('${prefix}org-1_channel-1'),
          'new session draft',
        );
      },
    );

    test('waits for a pending write before deleting the user prefix', () async {
      final service = SecureStorageService();
      const key = 'dm_draft_user-1_org-1_channel-1';

      final write = service.writeData(key, 'pending draft');
      final deletion = service.deleteValuesWithPrefix('dm_draft_user-1_');
      await Future.wait([write, deletion]);

      expect(await service.readData(key), isNull);
    });
  });
}
