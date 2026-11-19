import 'dart:io';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class MockPeopleRemoteDataSource extends Mock
    implements PeopleRemoteDataSource {}

void main() {
  late MockPeopleRemoteDataSource remote;
  late PeopleRepositoryImpl repository;

  setUp(() {
    remote = MockPeopleRemoteDataSource();
    repository = PeopleRepositoryImpl(remoteDataSource: remote);
  });

  void failWith(Object error) {
    when(
      () => remote.fetchMembers(
        orgId: any(named: 'orgId'),
        page: any(named: 'page'),
        search: any(named: 'search'),
      ),
    ).thenThrow(error);
  }

  test('passes an ApiFailure through unchanged', () async {
    const failure = ApiFailure(
      message: 'Server error',
      kind: ApiFailureKind.server,
    );
    failWith(failure);

    final result = await repository.fetchMembers(orgId: 'org-1');

    expect(result, isA<Failure<MembersPage>>());
    expect((result as Failure<MembersPage>).error, same(failure));
  });

  test('classifies an unexpected exception as unknown', () async {
    failWith(
      const SocketException('OS Error: Connection refused, errno = 111'),
    );

    final result = await repository.fetchMembers(orgId: 'org-1');

    final error = (result as Failure<MembersPage>).error;
    expect(error.kind, ApiFailureKind.unknown);
    expect(error.friendlyMessage, isNot(contains('errno')));
  });
}
