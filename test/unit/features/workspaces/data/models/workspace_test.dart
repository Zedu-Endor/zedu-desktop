import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

void main() {
  group('Workspace.membersLabel', () {
    Workspace workspace(int members) => Workspace(
      id: 'org-1',
      name: 'Cybertron',
      avatar: '',
      membersCount: members,
    );

    test('uses the plural for zero and many members', () {
      expect(workspace(0).membersLabel, '0 members');
      expect(workspace(5).membersLabel, '5 members');
    });

    test('uses the singular for one member', () {
      expect(workspace(1).membersLabel, '1 member');
    });
  });
}
