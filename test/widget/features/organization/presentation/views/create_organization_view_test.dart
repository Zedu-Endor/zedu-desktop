import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

// Fake notifier overrides build() so no GetIt/locator lookups happen.
class FakeUserProfileNotifier extends UserProfileNotifier {
  FakeUserProfileNotifier({UserProfileState initial = const UserProfileState()})
    : _initial = initial;

  final UserProfileState _initial;

  @override
  UserProfileState build() => _initial;
}

Widget buildCreateOrganizationUnderTest({
  UserProfileState profileState = const UserProfileState(),
}) {
  final router = GoRouter(
    initialLocation: AppRouter.createOrganization,
    routes: [
      GoRoute(
        path: AppRouter.home,
        builder: (context, state) => const SizedBox(),
      ),
      GoRoute(
        path: AppRouter.createOrganization,
        builder: (context, state) => const CreateOrganizationView(),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      userProfileNotifierProvider.overrideWith(
        () => FakeUserProfileNotifier(initial: profileState),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('CreateOrganizationView', () {
    testWidgets('renders the organization form', (tester) async {
      await tester.pumpWidget(buildCreateOrganizationUnderTest());
      await tester.pump();

      expect(find.text('Create Your Organization'), findsOneWidget);
      expect(find.text('Organization Name'), findsOneWidget);
      expect(find.text('Organization Type'), findsOneWidget);
      expect(find.text('Country'), findsOneWidget);
      expect(find.text('Submit'), findsOneWidget);
    });

    testWidgets('renders a cancel button as the way out', (tester) async {
      await tester.pumpWidget(buildCreateOrganizationUnderTest());
      await tester.pump();

      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('cancel is enabled while idle', (tester) async {
      await tester.pumpWidget(buildCreateOrganizationUnderTest());
      await tester.pump();

      final cancelButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Cancel'),
      );
      expect(cancelButton.onPressed, isNotNull);
    });

    testWidgets('disables cancel while saving', (tester) async {
      await tester.pumpWidget(
        buildCreateOrganizationUnderTest(
          profileState: const UserProfileState(isSaving: true),
        ),
      );
      await tester.pump();

      final cancelButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Cancel'),
      );
      expect(cancelButton.onPressed, isNull);
    });

    testWidgets('cancel navigates away from the form', (tester) async {
      // The form is taller than the default 800x600 test surface, so the
      // submit/cancel row starts off-screen.
      tester.view.physicalSize = const Size(1400, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(buildCreateOrganizationUnderTest());
      await tester.pump();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Create Your Organization'), findsNothing);
    });
  });
}
