import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class MockFilesRepository extends Mock implements FilesRepository {}

const _file = WorkspaceFile(id: 'f-1', name: 'logo.png');
const _grace = OrgMember(id: 'u-2', name: 'Grace Hopper');
const _alan = OrgMember(id: 'u-3', name: 'Alan Turing');

void main() {
  late MockFilesRepository repository;
  late ProviderContainer container;

  FileSharesNotifier notifier() => container.read(fileSharesProvider.notifier);

  setUpAll(() {
    registerFallbackValue(FileSharePermission.view);
    registerFallbackValue(FileShareAccess.invited);
  });

  setUp(() {
    repository = MockFilesRepository();
    container = ProviderContainer(
      overrides: [filesRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
  });

  void answer(Result<FileShareResult> result) => when(
    () => repository.shareFile(
      fileId: any(named: 'fileId'),
      recipientIds: any(named: 'recipientIds'),
      permission: any(named: 'permission'),
      access: any(named: 'access'),
      note: any(named: 'note'),
    ),
  ).thenAnswer((_) async => result);

  Future<FileShareOutcome> share(List<OrgMember> recipients) =>
      notifier().share(
        _file,
        recipients: recipients,
        permission: FileSharePermission.view,
        access: FileShareAccess.invited,
        note: '  Thanks  ',
      );

  test('names the one person it was sent to', () async {
    answer(const Success(FileShareResult(sentTo: ['u-2'])));

    final outcome = await share([_grace]);

    expect(outcome.shared, isTrue);
    expect(outcome.complete, isTrue);
    expect(
      outcome.message,
      'Shared logo.png with Grace Hopper by direct message.',
    );
    expect(container.read(fileSharesProvider), isEmpty);
    verify(
      () => repository.shareFile(
        fileId: 'f-1',
        recipientIds: ['u-2'],
        permission: FileSharePermission.view,
        access: FileShareAccess.invited,
        note: 'Thanks',
      ),
    ).called(1);
  });

  test('counts several people', () async {
    answer(const Success(FileShareResult(sentTo: ['u-2', 'u-3'])));

    final outcome = await share([_grace, _alan]);

    expect(outcome.message, 'Shared logo.png with 2 people by direct message.');
  });

  test('an empty server reply confirms nothing', () async {
    answer(const Success(FileShareResult()));

    final outcome = await share([_grace, _alan]);

    expect(outcome.shared, isFalse);
    expect(outcome.complete, isFalse);
    expect(outcome.message, 'Could not share logo.png. Please try again.');
  });

  test('counts server-confirmed recipients without a sent list', () async {
    answer(
      const Success(
        FileShareResult(
          recipients: [
            FileShareRecipientResult(userId: 'u-2', success: true),
            FileShareRecipientResult(userId: 'u-3', success: true),
          ],
        ),
      ),
    );

    final outcome = await share([_grace, _alan]);

    expect(outcome.shared, isTrue);
    expect(outcome.complete, isTrue);
    expect(outcome.message, 'Shared logo.png with 2 people by direct message.');
  });

  test('says who it could not be sent to', () async {
    answer(
      const Success(
        FileShareResult(
          sentTo: ['u-2'],
          recipients: [
            FileShareRecipientResult(userId: 'u-2', success: true),
            FileShareRecipientResult(userId: 'u-3'),
          ],
        ),
      ),
    );

    final outcome = await share([_grace, _alan]);

    expect(outcome.shared, isTrue);
    expect(outcome.complete, isFalse);
    expect(
      outcome.message,
      'Shared logo.png with 1 of 2 people. Alan Turing: not sent.',
    );
  });

  test('fails when it reached nobody', () async {
    answer(
      const Success(
        FileShareResult(
          recipients: [
            FileShareRecipientResult(userId: 'u-2', error: 'DM blocked'),
          ],
        ),
      ),
    );

    final outcome = await share([_grace]);

    expect(outcome.shared, isFalse);
    expect(
      outcome.message,
      'Could not share logo.png. Grace Hopper: DM blocked.',
    );
  });

  test('explains a refused share', () async {
    answer(
      const Failure(
        ApiFailure(message: 'Access denied', kind: ApiFailureKind.forbidden),
      ),
    );

    final outcome = await share([_grace]);

    expect(outcome.shared, isFalse);
    expect(
      outcome.message,
      'Could not share logo.png. Only its owner can share it.',
    );
    expect(container.read(fileSharesProvider), isEmpty);
  });

  test('needs at least one person', () async {
    final outcome = await share([]);

    expect(outcome.shared, isFalse);
    expect(outcome.message, 'Add at least one person.');
    verifyNever(
      () => repository.shareFile(
        fileId: any(named: 'fileId'),
        recipientIds: any(named: 'recipientIds'),
        permission: any(named: 'permission'),
        access: any(named: 'access'),
        note: any(named: 'note'),
      ),
    );
  });
}
