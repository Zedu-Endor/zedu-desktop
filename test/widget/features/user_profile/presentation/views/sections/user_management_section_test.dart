import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zedu/features/features.dart';

import '../../../../../../helpers/helpers.dart';

void main() {
  group('UserManagementSection', () {
    testWidgets(
      'renders Invites tab with count 0 by default when no invites exist',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: buildTestMaterialApp(
              Scaffold(
                body: UserManagementSection(
                  members: const [],
                  isSaving: false,
                  onInvite: ({required email, required role}) async {},
                  onUpdate: (_) {},
                  onRemove: (_) {},
                ),
              ),
            ),
          ),
        );

        expect(find.text('Invites'), findsOneWidget);
        expect(find.text('0'), findsNWidgets(2)); // Members (0) and Invites (0)
      },
    );

    testWidgets('renders Invites tab with configured invitesCount', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: buildTestMaterialApp(
            Scaffold(
              body: UserManagementSection(
                members: const [],
                isSaving: false,
                onInvite: ({required email, required role}) async {},
                onUpdate: (_) {},
                onRemove: (_) {},
                invitesCount: 5,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Invites'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });
  });
}
