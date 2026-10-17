import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../helpers/helpers.dart';
import '../../../unit/features/channels/starred_channel_test.dart'
    show MemoryStorage;

void main() {
  testWidgets(
    'keyboard starring and failed saves preserve existing shortcuts',
    (tester) async {
      final storage = MemoryStorage();
      final channel = Channel.fromJson({
        'channels_id': 'design',
        'name': 'design',
        'organisation_id': 'workspace',
      });
      final container = ProviderContainer(
        overrides: [
          channelScopeProvider.overrideWithValue((
            userId: 'user',
            workspaceId: 'workspace',
          )),
          starredChannelRepositoryProvider.overrideWithValue(
            StarredChannelRepositoryImpl(storage),
          ),
          workspaceChannelsProvider.overrideWithValue([channel]),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: buildTestMaterialApp(
            Scaffold(
              body: Column(
                children: [
                  ChannelStarButton(channel: channel),
                  const StarredChannelsSection(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Unstar channel'), findsOneWidget);
      expect(find.text('design'), findsOneWidget);
      storage.fail = true;
      await tester.tap(find.byTooltip('Unstar channel'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Unstar channel'), findsOneWidget);
      expect(find.text('Starred'), findsOneWidget);
      expect(find.text('design'), findsOneWidget);
      expect(
        find.text('Could not save starred channels. Try again.'),
        findsOneWidget,
      );
      storage.fail = false;
      await tester.tap(find.byTooltip('Unstar channel'));
      await tester.pumpAndSettle();
      expect(find.text('Starred'), findsNothing);
    },
  );
  testWidgets(
    'star icon, tooltips, sidebar collapse, navigation and unstar stay synchronized',
    (tester) async {
      final general = Channel(
        id: 'id-general',
        name: 'general',
        description: '',
        organisationId: 'workspace',
        ownerId: 'owner',
      );
      final design = general.copyWith(id: 'id-design', name: 'design');
      final container = ProviderContainer(
        overrides: [
          channelScopeProvider.overrideWithValue((
            userId: 'user',
            workspaceId: 'workspace',
          )),
          starredChannelRepositoryProvider.overrideWithValue(
            StarredChannelRepositoryImpl(MemoryStorage()),
          ),
          workspaceChannelsProvider.overrideWithValue([general, design]),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: buildTestMaterialApp(
            Scaffold(
              body: Column(
                children: [
                  ChannelStarButton(channel: design),
                  const StarredChannelsSection(),
                  ChannelSidebarItem(channel: general),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Star channel'), findsOneWidget);
      expect(find.byIcon(Icons.star_border_rounded), findsOneWidget);
      expect(find.text('Starred'), findsNothing);
      await tester.tap(find.byTooltip('Star channel'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Unstar channel'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      expect(find.text('design'), findsOneWidget);
      await tester.tap(find.text('Starred'));
      await tester.pumpAndSettle();
      expect(find.text('design'), findsNothing);
      await tester.tap(find.text('Starred'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('design'));
      await tester.pumpAndSettle();
      expect(container.read(selectedChannelProvider)?.id, design.id);
      expect(container.read(activeChatProvider).id, design.id);
      await tester.tap(find.text('general'));
      await tester.pumpAndSettle();
      expect(container.read(selectedChannelProvider)?.id, general.id);
      expect(container.read(activeChatProvider).id, general.id);
      await tester.tap(find.byTooltip('Unstar channel'));
      await tester.pumpAndSettle();
      expect(find.text('Starred'), findsNothing);
      expect(find.text('design'), findsNothing);
      expect(find.text('general'), findsOneWidget);
      expect(find.byTooltip('Star channel'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
