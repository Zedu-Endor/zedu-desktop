import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class _FakeGoRouterState extends Fake implements GoRouterState {
  @override
  final Uri uri;

  _FakeGoRouterState(String path) : uri = Uri.parse(path);
}

void main() {
  setUp(() {
    AppRouter.authStatus.value = AuthStatus.unknown;
  });

  tearDown(() {
    AppRouter.authStatus.value = AuthStatus.unknown;
  });

  group('AppRouter.redirectSignedOut', () {
    test(
      'does not redirect any route while auth status is unknown (session restoring)',
      () {
        AppRouter.authStatus.value = AuthStatus.unknown;

        expect(
          AppRouter.redirectSignedOut(_FakeGoRouterState(AppRouter.home)),
          isNull,
        );
        expect(
          AppRouter.redirectSignedOut(_FakeGoRouterState(AppRouter.login)),
          isNull,
        );
        expect(
          AppRouter.redirectSignedOut(_FakeGoRouterState(AppRouter.profile)),
          isNull,
        );
        expect(
          AppRouter.redirectSignedOut(
            _FakeGoRouterState(AppRouter.createOrganization),
          ),
          isNull,
        );
      },
    );

    test('redirects unauthenticated users from protected routes to login', () {
      AppRouter.authStatus.value = AuthStatus.unauthenticated;

      expect(
        AppRouter.redirectSignedOut(_FakeGoRouterState(AppRouter.home)),
        AppRouter.login,
      );
      expect(
        AppRouter.redirectSignedOut(_FakeGoRouterState(AppRouter.profile)),
        AppRouter.login,
      );
      expect(
        AppRouter.redirectSignedOut(
          _FakeGoRouterState(AppRouter.createOrganization),
        ),
        AppRouter.login,
      );
      expect(
        AppRouter.redirectSignedOut(_FakeGoRouterState(AppRouter.buyCredits)),
        AppRouter.login,
      );
      expect(
        AppRouter.redirectSignedOut(_FakeGoRouterState('/channels/general')),
        AppRouter.login,
      );
    });

    test(
      'allows unauthenticated users on public routes without redirecting',
      () {
        AppRouter.authStatus.value = AuthStatus.unauthenticated;

        expect(
          AppRouter.redirectSignedOut(_FakeGoRouterState(AppRouter.login)),
          isNull,
        );
        expect(
          AppRouter.redirectSignedOut(_FakeGoRouterState(AppRouter.signup)),
          isNull,
        );
        expect(
          AppRouter.redirectSignedOut(
            _FakeGoRouterState(AppRouter.magicLinkRequest),
          ),
          isNull,
        );
        expect(
          AppRouter.redirectSignedOut(
            _FakeGoRouterState(AppRouter.magicLinkSent),
          ),
          isNull,
        );
        expect(
          AppRouter.redirectSignedOut(
            _FakeGoRouterState(AppRouter.forgotPassword),
          ),
          isNull,
        );
        expect(
          AppRouter.redirectSignedOut(
            _FakeGoRouterState(AppRouter.resetPassword),
          ),
          isNull,
        );
        expect(
          AppRouter.redirectSignedOut(
            _FakeGoRouterState(AppRouter.changePassword),
          ),
          isNull,
        );
      },
    );

    test(
      'redirects authenticated users away from entry auth routes to home',
      () {
        AppRouter.authStatus.value = AuthStatus.authenticated;

        expect(
          AppRouter.redirectSignedOut(_FakeGoRouterState(AppRouter.login)),
          AppRouter.home,
        );
        expect(
          AppRouter.redirectSignedOut(_FakeGoRouterState(AppRouter.signup)),
          AppRouter.home,
        );
        expect(
          AppRouter.redirectSignedOut(
            _FakeGoRouterState(AppRouter.magicLinkRequest),
          ),
          AppRouter.home,
        );
        expect(
          AppRouter.redirectSignedOut(
            _FakeGoRouterState(AppRouter.magicLinkSent),
          ),
          AppRouter.home,
        );
        expect(
          AppRouter.redirectSignedOut(
            _FakeGoRouterState(AppRouter.forgotPassword),
          ),
          AppRouter.home,
        );
        expect(
          AppRouter.redirectSignedOut(
            _FakeGoRouterState(AppRouter.resetPassword),
          ),
          AppRouter.home,
        );
      },
    );

    test(
      'allows authenticated users on protected routes without redirecting',
      () {
        AppRouter.authStatus.value = AuthStatus.authenticated;

        expect(
          AppRouter.redirectSignedOut(_FakeGoRouterState(AppRouter.home)),
          isNull,
        );
        expect(
          AppRouter.redirectSignedOut(_FakeGoRouterState(AppRouter.profile)),
          isNull,
        );
        expect(
          AppRouter.redirectSignedOut(
            _FakeGoRouterState(AppRouter.createOrganization),
          ),
          isNull,
        );
        expect(
          AppRouter.redirectSignedOut(_FakeGoRouterState(AppRouter.buyCredits)),
          isNull,
        );
        expect(
          AppRouter.redirectSignedOut(_FakeGoRouterState('/channels/123')),
          isNull,
        );
      },
    );
  });
}
