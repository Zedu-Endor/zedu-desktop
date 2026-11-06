import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../../helpers/helpers.dart';

void main() {
  testWidgets('renders organization avatar container with primaryBg token', (
    tester,
  ) async {
    const org = OrganizationProfile(
      id: 'org-1',
      name: 'Acme Corp',
      natureOfBusiness: 'Technology',
      country: 'US',
    );

    await tester.pumpWidget(
      buildTestMaterialApp(
        Scaffold(
          body: OrganizationSection(
            organization: org,
            onSave: (_) {},
            onDelete: () async {},
            onLeave: () async {},
          ),
        ),
      ),
    );

    expect(find.text('AC'), findsOneWidget);
    final containerFinder = find.ancestor(
      of: find.text('AC'),
      matching: find.byType(Container),
    );
    expect(containerFinder, findsWidgets);

    final containerWidget = tester.widget<Container>(containerFinder.first);
    final decoration = containerWidget.decoration as BoxDecoration?;
    expect(decoration?.color, equals(AppPalette.light.primaryBg));
  });
}
