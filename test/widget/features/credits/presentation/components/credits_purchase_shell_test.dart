import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.authenticated);
}

class _FakeUserProfileNotifier extends UserProfileNotifier {
  @override
  UserProfileState build() => const UserProfileState();
}

class _FakeCreditsNotifier extends CreditsNotifier {
  @override
  CreditsState build() => const CreditsState();

  @override
  Future<void> load({String? orgId}) async {}
}

class _FakeWorkspaceNotifier extends WorkspaceNotifier {
  @override
  WorkspaceState build() => const WorkspaceState();
}

void main() {
  setUp(() {
    if (locator.isRegistered<AppConfig>()) {
      locator.unregister<AppConfig>();
    }
    locator.registerSingleton<AppConfig>(
      const AppConfig(apiBaseUrl: 'http://test', usesMockData: false),
    );
  });

  tearDown(() {
    if (locator.isRegistered<AppConfig>()) {
      locator.unregister<AppConfig>();
    }
  });

  testWidgets('page background comes from the theme palette (Ziki #568)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
          userProfileNotifierProvider.overrideWith(
            _FakeUserProfileNotifier.new,
          ),
          creditsNotifierProvider.overrideWith(_FakeCreditsNotifier.new),
          workspaceProvider.overrideWith(_FakeWorkspaceNotifier.new),
        ],
        child: buildTestMaterialApp(
          const CreditsPurchaseShell(child: SizedBox.shrink()),
        ),
      ),
    );
    await tester.pump();

    final scaffold = tester.widget<Scaffold>(
      find
          .ancestor(
            of: find.byType(AppSidebarRail),
            matching: find.byType(Scaffold),
          )
          .first,
    );
    final context = tester.element(find.byType(CreditsPurchaseShell));

    expect(scaffold.backgroundColor, context.colors.background);
    expect(scaffold.backgroundColor, isNot(Colors.white));
  });
}
