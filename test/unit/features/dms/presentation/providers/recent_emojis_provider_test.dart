import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

void main() {
  group('recentEmojisProvider (Ziki #3433)', () {
    late ProviderContainer container;
    RecentEmojisNotifier notifier() =>
        container.read(recentEmojisProvider.notifier);
    List<String> recent() => container.read(recentEmojisProvider);

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    test('starts empty', () {
      expect(recent(), isEmpty);
    });

    test('puts the newest pick first', () {
      notifier()
        ..add('👍')
        ..add('🎉');

      expect(recent(), ['🎉', '👍']);
    });

    test('picking an emoji again moves it to the front once', () {
      notifier()
        ..add('👍')
        ..add('🎉')
        ..add('👍');

      expect(recent(), ['👍', '🎉']);
    });

    test('keeps at most 8, dropping the oldest', () {
      const picks = [
        '1️⃣',
        '2️⃣',
        '3️⃣',
        '4️⃣',
        '5️⃣',
        '6️⃣',
        '7️⃣',
        '8️⃣',
        '9️⃣',
      ];
      for (final emoji in picks) {
        notifier().add(emoji);
      }

      expect(recent(), hasLength(RecentEmojisNotifier.maxCount));
      expect(recent().first, '9️⃣');
      expect(recent(), isNot(contains('1️⃣')));
    });
  });
}
