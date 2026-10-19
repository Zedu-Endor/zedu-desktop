import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

void main() {
  testWidgets(
    'member avatars survive empty, whitespace, and leading-space names',
    (tester) async {
      TeamMember member({String? name, required String email}) {
        return TeamMember(
          id: email.isEmpty ? 'blank' : email,
          email: email,
          role: 'member',
          dateJoined: '2026-01-01',
          status: TeamMemberStatus.active,
          name: name,
        );
      }

      await tester.pumpWidget(
        buildTestMaterialApp(
          Scaffold(
            body: GroupDetailsPanel(
              group: GroupDM(
                id: 'g1',
                name: 'Design',
                members: [
                  member(name: ' John', email: 'john@zedu.chat'),
                  member(name: '', email: ''),
                  member(name: '   ', email: 'ada@zedu.chat'),
                ],
              ),
              onClose: () {},
              onRename: (_) {},
              onLeave: () {},
            ),
          ),
        ),
      );

      expect(find.text('J'), findsOneWidget);
      expect(find.text('?'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
    },
  );
}
