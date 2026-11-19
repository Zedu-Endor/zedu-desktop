import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

void main() {
  group('SidebarVisibilityNotifier', () {
    test('the main sidebar starts visible', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(sidebarVisibilityProvider), isTrue);
    });

    test('toggles between hidden and visible', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(sidebarVisibilityProvider.notifier);

      notifier.toggle();
      expect(container.read(sidebarVisibilityProvider), isFalse);

      notifier.toggle();
      expect(container.read(sidebarVisibilityProvider), isTrue);
    });

    test('hide and show set the state directly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(sidebarVisibilityProvider.notifier);

      notifier.hide();
      notifier.hide();
      expect(container.read(sidebarVisibilityProvider), isFalse);

      notifier.show();
      notifier.show();
      expect(container.read(sidebarVisibilityProvider), isTrue);
    });
  });
}
