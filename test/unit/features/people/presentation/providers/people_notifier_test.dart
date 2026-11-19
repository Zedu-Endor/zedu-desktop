import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class MockDmRepository extends Mock implements DmRepository {}

class _FakePeopleRepository implements PeopleRepository {
  final requests = <(int, String)>[];
  bool failPage2 = false;

  @override
  Future<Result<MembersPage>> fetchMembers({
    required String orgId,
    int page = 1,
    String search = '',
  }) async {
    requests.add((page, search));
    if (page == 2 && failPage2) {
      return const Failure(ApiFailure(message: 'offline'));
    }
    return Success(
      MembersPage(
        members: page == 1
            ? const [
                OrgMember(id: 'u-1', name: 'Ada'),
                OrgMember(id: 'u-2', name: 'Grace'),
              ]
            // u-2 again: pages can overlap when someone joins meanwhile.
            : const [
                OrgMember(id: 'u-2', name: 'Grace'),
                OrgMember(id: 'u-3', name: 'Linus'),
              ],
        currentPage: page,
        totalPages: 2,
        totalItems: 3,
      ),
    );
  }
}

class _SwitchableOrg extends Notifier<String> {
  @override
  String build() => 'org-a';

  void select(String orgId) => state = orgId;
}

final _switchableOrgProvider = NotifierProvider<_SwitchableOrg, String>(
  _SwitchableOrg.new,
);

/// Returns one member per org page, except held pages which wait until the
/// test completes them.
class _HeldPagePeopleRepository implements PeopleRepository {
  final held = <String, Completer<Result<MembersPage>>>{};

  void hold(String orgId, int page) =>
      held['$orgId/$page'] = Completer<Result<MembersPage>>();

  MembersPage _page(String orgId, int page) => MembersPage(
    members: [OrgMember(id: '$orgId-m$page', name: '$orgId member $page')],
    currentPage: page,
    totalPages: 2,
    totalItems: 2,
  );

  @override
  Future<Result<MembersPage>> fetchMembers({
    required String orgId,
    int page = 1,
    String search = '',
  }) {
    final completer = held['$orgId/$page'];
    if (completer != null) return completer.future;
    return Future.value(Success(_page(orgId, page)));
  }
}

void main() {
  late _FakePeopleRepository people;
  late MockDmRepository dms;
  late ProviderContainer container;

  setUp(() {
    people = _FakePeopleRepository();
    dms = MockDmRepository();
    container = ProviderContainer(
      overrides: [
        currentOrgIdProvider.overrideWithValue('org-1'),
        peopleRepositoryProvider.overrideWithValue(people),
        dmRepositoryProvider.overrideWithValue(dms),
      ],
    );
    addTearDown(container.dispose);
  });

  group('PeopleListNotifier', () {
    test('loads the first page for its search', () async {
      final sub = container.listen(peopleListProvider('ada'), (_, _) {});
      addTearDown(sub.close);

      final list = await container.read(peopleListProvider('ada').future);

      expect(people.requests, [(1, 'ada')]);
      expect(list.members.map((m) => m.id), ['u-1', 'u-2']);
      expect(list.hasMore, isTrue);
      expect(list.total, 3);
    });

    test('load more adds the next page without duplicates', () async {
      final sub = container.listen(peopleListProvider(''), (_, _) {});
      addTearDown(sub.close);
      await container.read(peopleListProvider('').future);

      await container.read(peopleListProvider('').notifier).loadMore();

      final list = container.read(peopleListProvider('')).value!;
      expect(list.members.map((m) => m.id), ['u-1', 'u-2', 'u-3']);
      expect(list.hasMore, isFalse);

      // Nothing more to load.
      await container.read(peopleListProvider('').notifier).loadMore();
      expect(people.requests, [(1, ''), (2, '')]);
    });

    test('a failed load more keeps the members and can retry', () async {
      people.failPage2 = true;
      final sub = container.listen(peopleListProvider(''), (_, _) {});
      addTearDown(sub.close);
      await container.read(peopleListProvider('').future);

      await container.read(peopleListProvider('').notifier).loadMore();

      final list = container.read(peopleListProvider('')).value!;
      expect(list.members, hasLength(2));
      expect(list.loadMoreFailed, isTrue);
      expect(list.hasMore, isTrue);

      // The guard must not keep blocking once the failure is reported.
      people.failPage2 = false;
      await container.read(peopleListProvider('').notifier).loadMore();

      final retried = container.read(peopleListProvider('')).value!;
      expect(retried.members.map((m) => m.id), ['u-1', 'u-2', 'u-3']);
      expect(retried.loadMoreFailed, isFalse);
      expect(retried.hasMore, isFalse);
    });

    test(
      'a load more from the previous workspace is dropped after a switch',
      () async {
        final repository = _HeldPagePeopleRepository();
        final workspaceContainer = ProviderContainer(
          overrides: [
            currentOrgIdProvider.overrideWith(
              (ref) => ref.watch(_switchableOrgProvider),
            ),
            peopleRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(workspaceContainer.dispose);

        final sub = workspaceContainer.listen(
          peopleListProvider(''),
          (_, _) {},
        );
        addTearDown(sub.close);
        await workspaceContainer.read(peopleListProvider('').future);
        expect(
          workspaceContainer
              .read(peopleListProvider(''))
              .value!
              .members
              .map((m) => m.id),
          ['org-a-m1'],
        );

        repository.hold('org-a', 2);
        final pending = workspaceContainer
            .read(peopleListProvider('').notifier)
            .loadMore();

        workspaceContainer
            .read(_switchableOrgProvider.notifier)
            .select('org-b');
        await workspaceContainer.read(peopleListProvider('').future);
        expect(
          workspaceContainer
              .read(peopleListProvider(''))
              .value!
              .members
              .map((m) => m.id),
          ['org-b-m1'],
        );

        repository.held['org-a/2']!.complete(
          Success<MembersPage>(repository._page('org-a', 2)),
        );
        await pending;

        expect(
          workspaceContainer
              .read(peopleListProvider(''))
              .value!
              .members
              .map((m) => m.id),
          ['org-b-m1'],
        );
      },
    );

    test(
      'a failed load more from the previous workspace is dropped after a switch',
      () async {
        final repository = _HeldPagePeopleRepository();
        final workspaceContainer = ProviderContainer(
          overrides: [
            currentOrgIdProvider.overrideWith(
              (ref) => ref.watch(_switchableOrgProvider),
            ),
            peopleRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(workspaceContainer.dispose);

        final sub = workspaceContainer.listen(
          peopleListProvider(''),
          (_, _) {},
        );
        addTearDown(sub.close);
        await workspaceContainer.read(peopleListProvider('').future);

        repository.hold('org-a', 2);
        final pending = workspaceContainer
            .read(peopleListProvider('').notifier)
            .loadMore();

        workspaceContainer
            .read(_switchableOrgProvider.notifier)
            .select('org-b');
        await workspaceContainer.read(peopleListProvider('').future);

        repository.held['org-a/2']!.complete(
          const Failure<MembersPage>(ApiFailure(message: 'offline')),
        );
        await pending;

        final list = workspaceContainer.read(peopleListProvider('')).value!;
        expect(list.members.map((m) => m.id), ['org-b-m1']);
        expect(list.loadMoreFailed, isFalse);
      },
    );
  });

  group('PeopleActionsNotifier.openChat', () {
    const ada = OrgMember(id: 'u-1', name: 'Ada', email: 'ada@zedu.test');

    test('opens the DM and shows it in the DMs tab', () async {
      when(
        () => dms.openConversation(orgId: 'org-1', participantId: 'u-1'),
      ).thenAnswer((_) async => (channelId: 'c-1', participantId: 'u-1'));

      final opened = await container
          .read(peopleActionsProvider.notifier)
          .openChat(ada);

      expect(opened, isTrue);
      final dm = container.read(selectedDmProvider)!;
      expect(dm.channelId, 'c-1');
      expect(dm.displayName, 'Ada');
      expect(dm.participantEmail, 'ada@zedu.test');
      expect(container.read(homeSidebarProvider), HomeSidebarType.dms);
      expect(container.read(peopleActionsProvider), isNull);
    });

    test('reports a failure and stays on People', () async {
      when(
        () => dms.openConversation(orgId: 'org-1', participantId: 'u-1'),
      ).thenThrow(const ApiFailure(message: 'offline'));
      container
          .read(homeSidebarProvider.notifier)
          .setType(HomeSidebarType.people);

      final opened = await container
          .read(peopleActionsProvider.notifier)
          .openChat(ada);

      expect(opened, isFalse);
      expect(container.read(selectedDmProvider), isNull);
      expect(container.read(homeSidebarProvider), HomeSidebarType.people);
      expect(container.read(peopleActionsProvider), isNull);
    });
  });
}
