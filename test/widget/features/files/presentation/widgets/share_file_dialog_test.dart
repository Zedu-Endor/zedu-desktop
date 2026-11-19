import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class _FakeWorkspaceNotifier extends WorkspaceNotifier {
  @override
  WorkspaceState build() => const WorkspaceState(
    selectedWorkspace: Workspace(id: 'org-1', name: 'Workspace A', avatar: ''),
  );
}

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._initial);

  final AuthState _initial;

  @override
  AuthState build() => _initial;
}

final _me = User(
  id: 'me',
  firstName: 'Dave',
  lastName: 'Tolu',
  email: 'dave@zedu.test',
  phone: '',
  username: 'dave',
  isVerified: true,
  isOnboarded: true,
  createdAt: DateTime(2026, 10, 16),
  currentOrg: 'org-1',
  currentOrganisationSlug: 'org-1',
  avatarUrl: '',
  defaultAvatarUrl: '',
);

/// Every member whose name contains the search, the signed-in user included,
/// as `GET /organisations/{id}/users` returns them.
class _FakePeopleRepository implements PeopleRepository {
  static const members = [
    OrgMember(id: 'me', name: 'Dave Tolu', email: 'dave@zedu.test'),
    OrgMember(id: 'u-2', name: 'Dave Grohl', email: 'grohl@zedu.test'),
  ];

  @override
  Future<Result<MembersPage>> fetchMembers({
    required String orgId,
    int page = 1,
    String search = '',
  }) async {
    final query = search.toLowerCase();
    final found = [
      for (final m in members)
        if (m.name.toLowerCase().contains(query)) m,
    ];
    return Success(
      MembersPage(
        members: found,
        currentPage: 1,
        totalPages: 1,
        totalItems: found.length,
      ),
    );
  }
}

void main() {
  Finder peopleField() => find.byKey(const ValueKey('share-people-field'));

  Future<void> pumpDialog(WidgetTester tester, {User? user}) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workspaceProvider.overrideWith(_FakeWorkspaceNotifier.new),
          authNotifierProvider.overrideWith(
            () => _FakeAuthNotifier(
              AuthState(status: AuthStatus.authenticated, user: user),
            ),
          ),
          peopleRepositoryProvider.overrideWithValue(_FakePeopleRepository()),
        ],
        child: buildTestMaterialApp(
          const Scaffold(
            body: ShareFileDialog(
              file: WorkspaceFile(id: 'f-1', name: 'logo.png'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(peopleField(), text);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
  }

  testWidgets('does not suggest the signed-in user', (tester) async {
    await pumpDialog(tester, user: _me);

    await search(tester, 'dave');

    expect(find.text('Dave Grohl'), findsOneWidget);
    expect(find.text('Dave Tolu'), findsNothing);
  });

  testWidgets('searching only your own name finds nobody to add', (
    tester,
  ) async {
    await pumpDialog(tester, user: _me);

    await search(tester, 'tolu');
    expect(find.text('Dave Tolu'), findsNothing);
    expect(find.text('No workspace member matches.'), findsOneWidget);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byType(InputChip), findsNothing);
  });

  testWidgets('other members can still be added', (tester) async {
    await pumpDialog(tester, user: _me);

    await search(tester, 'dave');
    await tester.tap(find.text('Dave Grohl'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(InputChip, 'Dave Grohl'), findsOneWidget);
  });

  testWidgets('suggests everyone when no user is signed in', (tester) async {
    await pumpDialog(tester);

    await search(tester, 'dave');

    expect(find.text('Dave Grohl'), findsOneWidget);
    expect(find.text('Dave Tolu'), findsOneWidget);
  });
}
