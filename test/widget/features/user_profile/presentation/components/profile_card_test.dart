import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

void main() {
  testWidgets('ProfileCard binds background and border to theme tokens', (
    tester,
  ) async {
    BuildContext? testContext;
    await tester.pumpWidget(
      buildTestMaterialApp(
        Builder(
          builder: (context) {
            testContext = context;
            return const Scaffold(
              body: ProfileCard(child: Text('Card Content')),
            );
          },
        ),
      ),
    );

    expect(find.text('Card Content'), findsOneWidget);

    final container = tester.widget<Container>(
      find.byWidgetPredicate(
        (w) => w is Container && w.decoration is BoxDecoration,
      ),
    );

    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, equals(testContext!.colors.background));

    final border = decoration.border as Border?;
    expect(border?.top.color, equals(testContext!.colors.divider));
  });
}
