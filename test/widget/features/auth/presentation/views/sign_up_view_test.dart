import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

// Fake notifier that avoids locator setup while staying type-compatible with
// authNotifierProvider. Mirrors the real signUp contract: loading while the
// sign-up → auto-login chain runs, then either authenticated or an error.
class FakeAuthNotifier extends AuthNotifier {
  FakeAuthNotifier({
    this.failSignUp = false,
    void Function(String username, String email, String password)? onSignUp,
    Future<void>? pendingSignUp,
  }) : _onSignUp = onSignUp,
       _pendingSignUp = pendingSignUp;

  final bool failSignUp;
  final void Function(String, String, String)? _onSignUp;
  final Future<void>? _pendingSignUp;
  int signUpCalls = 0;
  int googleCalls = 0;

  @override
  Future<void> loginWithGoogle() async {
    googleCalls++;
    state = AuthState(status: AuthStatus.authenticated);
  }

  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);

  @override
  Future<void> signUp({
    required String username,
    required String email,
    required String password,
  }) async {
    signUpCalls++;
    state = state.copyWith(isLoading: true);
    _onSignUp?.call(username, email, password);
    await _pendingSignUp;
    if (failSignUp) {
      state = state.copyWith(isLoading: false, error: 'Sign up failed');
    } else {
      state = AuthState(status: AuthStatus.authenticated);
    }
  }
}

Widget buildSignUpViewUnderTest({required FakeAuthNotifier notifier}) {
  final router = GoRouter(
    initialLocation: AppRouter.signup,
    routes: [
      GoRoute(path: AppRouter.signup, builder: (_, _) => const SignUpView()),
      GoRoute(
        path: AppRouter.home,
        builder: (_, _) =>
            const Scaffold(body: Center(child: Text('HOME-STUB'))),
      ),
    ],
  );
  return ProviderScope(
    overrides: [authNotifierProvider.overrideWith(() => notifier)],
    child: MaterialApp.router(routerConfig: router),
  );
}

Finder get createAccountButton =>
    find.widgetWithText(ElevatedButton, 'Create Account');

// AppToastService auto-dismisses on a 4s timer; let it fire before the test
// ends so no timer is left pending.
Future<void> drainToastTimer(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle();
}

void main() {
  group('SignUpView', () {
    Future<void> pumpDesktopSignUp(
      WidgetTester tester,
      FakeAuthNotifier notifier,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(buildSignUpViewUnderTest(notifier: notifier));
      await tester.pump();
    }

    Future<void> fillValidForm(WidgetTester tester) async {
      await tester.enterText(find.byType(TextFormField).at(0), 'vader01');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'vader01@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(2), 'Record123');
    }

    testWidgets('legal line reads "By signing up" in sentence case', (
      tester,
    ) async {
      await pumpDesktopSignUp(tester, FakeAuthNotifier());

      expect(
        find.textContaining(
          'By signing up, you agree to our Terms of Service and Privacy Policy',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('By Signing up', findRichText: true),
        findsNothing,
      );
    });

    testWidgets('navigates to home after a successful sign-up', (tester) async {
      await pumpDesktopSignUp(tester, FakeAuthNotifier());
      await fillValidForm(tester);

      await tester.ensureVisible(createAccountButton);
      await tester.tap(createAccountButton);
      await tester.pumpAndSettle();

      expect(find.text('HOME-STUB'), findsOneWidget);
      expect(find.text('Create Account'), findsNothing);
      await drainToastTimer(tester);
    });

    testWidgets(
      'Create Account cannot be double-submitted while the chain is in flight',
      (tester) async {
        final pending = Completer<void>();
        final notifier = FakeAuthNotifier(pendingSignUp: pending.future);
        await pumpDesktopSignUp(tester, notifier);
        await fillValidForm(tester);

        await tester.ensureVisible(createAccountButton);
        await tester.tap(createAccountButton);
        await tester.pump();

        expect(
          tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
          isNull,
        );

        await tester.tap(find.byType(ElevatedButton));
        await tester.pump();
        expect(notifier.signUpCalls, 1);

        pending.complete();
        await tester.pumpAndSettle();
        expect(find.text('HOME-STUB'), findsOneWidget);
        await drainToastTimer(tester);
      },
    );

    testWidgets('rejects a password that ends with a space', (tester) async {
      final notifier = FakeAuthNotifier();
      await pumpDesktopSignUp(tester, notifier);
      await fillValidForm(tester);
      await tester.enterText(find.byType(TextFormField).at(2), 'Record123 ');

      await tester.ensureVisible(createAccountButton);
      await tester.tap(createAccountButton);
      await tester.pumpAndSettle();

      expect(find.text(Validators.passwordEdgeSpaceMessage), findsOneWidget);
      expect(notifier.signUpCalls, 0);
    });

    testWidgets('does not count leading spaces towards the length', (
      tester,
    ) async {
      final notifier = FakeAuthNotifier();
      await pumpDesktopSignUp(tester, notifier);
      await fillValidForm(tester);
      await tester.enterText(find.byType(TextFormField).at(2), '       a');

      await tester.ensureVisible(createAccountButton);
      await tester.tap(createAccountButton);
      await tester.pumpAndSettle();

      expect(find.text(Validators.passwordEdgeSpaceMessage), findsOneWidget);
      expect(notifier.signUpCalls, 0);
    });

    testWidgets('sends the password exactly as typed', (tester) async {
      String? sentPassword;
      await pumpDesktopSignUp(
        tester,
        FakeAuthNotifier(onSignUp: (_, _, password) => sentPassword = password),
      );
      await fillValidForm(tester);
      await tester.enterText(find.byType(TextFormField).at(2), 'Record 123');

      await tester.ensureVisible(createAccountButton);
      await tester.tap(createAccountButton);
      await tester.pumpAndSettle();

      expect(sentPassword, 'Record 123');
      await drainToastTimer(tester);
    });

    testWidgets('stays on the form when sign-up fails', (tester) async {
      await pumpDesktopSignUp(tester, FakeAuthNotifier(failSignUp: true));
      await fillValidForm(tester);

      await tester.ensureVisible(createAccountButton);
      await tester.tap(createAccountButton);
      await tester.pumpAndSettle();

      expect(find.text('HOME-STUB'), findsNothing);
      expect(find.text('Sign up failed'), findsOneWidget);
      expect(createAccountButton, findsOneWidget);
      await drainToastTimer(tester);
    });

    testWidgets('"Sign up with Google" starts the Google flow', (tester) async {
      final notifier = FakeAuthNotifier();
      await pumpDesktopSignUp(tester, notifier);

      final google = find.text('Sign up with Google');
      await tester.ensureVisible(google);
      await tester.tap(google);
      await tester.pumpAndSettle();

      expect(notifier.googleCalls, 1);
      expect(find.text('Google sign up is not available yet.'), findsNothing);
      // The Google account is signed in, so the user lands on home.
      expect(find.text('HOME-STUB'), findsOneWidget);
      await drainToastTimer(tester);
    });
  });
}
