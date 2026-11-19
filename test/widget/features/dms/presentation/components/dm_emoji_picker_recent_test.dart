import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

void main() {
  group('DmEmojiPicker Recently used row (Ziki #3433)', () {
    late List<String> picked;

    Future<ProviderContainer> pumpPicker(
      WidgetTester tester, {
      ProviderContainer? container,
    }) async {
      final scope = container ?? ProviderContainer();
      if (container == null) addTearDown(scope.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: scope,
          child: buildTestMaterialApp(
            Scaffold(
              body: Center(
                child: DmEmojiPicker(
                  onEmojiSelected: picked.add,
                  onClose: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return scope;
    }

    setUp(() => picked = []);

    testWidgets('is hidden before anything is picked', (tester) async {
      await pumpPicker(tester);

      expect(find.text('Recently used'), findsNothing);
    });

    testWidgets('shows picks newest first after reopening the picker', (
      tester,
    ) async {
      final container = await pumpPicker(tester);
      await tester.tap(find.text('😀'));
      await tester.tap(find.text('😃'));
      await tester.pump();

      // Close and reopen: the list outlives the picker for the session.
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpPicker(tester, container: container);

      expect(find.text('Recently used'), findsOneWidget);
      final first = tester.getTopLeft(
        find.byKey(const ValueKey('recent-emoji-😃')),
      );
      final second = tester.getTopLeft(
        find.byKey(const ValueKey('recent-emoji-😀')),
      );
      expect(first.dx, lessThan(second.dx));
      container.dispose();
    });

    testWidgets('picking from the row reports that emoji', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(recentEmojisProvider.notifier).add('🚀');
      await pumpPicker(tester, container: container);

      await tester.tap(find.byKey(const ValueKey('recent-emoji-🚀')));

      expect(picked, ['🚀']);
    });

    testWidgets('each recent emoji is a labelled button', (tester) async {
      final handle = tester.ensureSemantics();
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(recentEmojisProvider.notifier).add('🔥');
      await pumpPicker(tester, container: container);

      expect(
        tester.getSemantics(find.bySemanticsLabel('Recently used 🔥')),
        matchesSemantics(
          label: 'Recently used 🔥',
          isButton: true,
          hasTapAction: true,
        ),
      );
      expect(find.byTooltip('Recently used 🔥'), findsOneWidget);
      handle.dispose();
    });
  });
}
