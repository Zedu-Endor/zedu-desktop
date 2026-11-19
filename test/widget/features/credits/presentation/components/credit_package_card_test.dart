import 'package:zedu/core/core.dart';
import 'package:zedu/features/credits/credits.dart';

import '../../../../../helpers/helpers.dart';

void main() {
  testWidgets('renders package title and description with theme tokens', (
    tester,
  ) async {
    const package = CreditPackage(
      id: 'pkg-1',
      name: 'Pro Tier',
      description: 'Ideal for scaling teams',
      price: 29,
      credits: 1000,
      benefits: ['Priority support', 'Dedicated server'],
    );

    await tester.pumpWidget(
      buildTestMaterialApp(
        Scaffold(
          body: CreditPackageCard(
            package: package,
            accentColor: const Color(0xFF6458F5),
            isCurrentPlan: false,
            onPurchase: () {},
          ),
        ),
      ),
    );

    final titleWidget = tester.widget<Text>(find.text('Pro Tier'));
    final descWidget = tester.widget<Text>(
      find.text('Ideal for scaling teams'),
    );

    expect(titleWidget.style?.color, equals(AppPalette.light.textPrimary));
    expect(descWidget.style?.color, equals(AppPalette.light.textSecondary));
  });
}
