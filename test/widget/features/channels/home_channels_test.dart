import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../helpers/helpers.dart';
import '../../../unit/features/channels/starred_channel_test.dart'
    show MemoryStorage;

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

class _Workspaces extends WorkspaceNotifier {
  @override
  WorkspaceState build() => const WorkspaceState();
}

class _Channels extends ChannelNotifier {
  static bool createSucceeds = false;

  @override
  Future<bool> createChannel({
    required String name,
    required String description,
    required bool isPrivate,
    String? topic,
  }) async => createSucceeds;

  @override
  ChannelState build() => ChannelState(
    channels: [
      channel,
      channel.copyWith(id: 'design', name: 'design'),
    ],
  );

  static final channel = Channel.fromJson({
    'channels_id': 'general',
    'name': 'general',
    'description': '',
    'organisation_id': 'workspace',
    'owner_id': 'owner',
  });
}

void main() {
  testWidgets(
    'home sidebar fills height and supports starring, directory and creation',
    (tester) async {
      _Channels.createSucceeds = false;
      tester.view.physicalSize = const Size(1264, 680);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final storage = MemoryStorage();
      final app = ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_Auth.new),
          workspaceProvider.overrideWith(_Workspaces.new),
          channelProvider.overrideWith(_Channels.new),
          orgCreditBalanceProvider.overrideWithValue(0),
          channelScopeProvider.overrideWithValue((
            userId: 'user',
            workspaceId: 'workspace',
          )),
          starredChannelRepositoryProvider.overrideWithValue(
            StarredChannelRepositoryImpl(storage),
          ),
        ],
        child: buildTestMaterialApp(const HomeView()),
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(find.byType(ChannelStarButton)).dx,
        lessThan(tester.getTopLeft(find.text('# general')).dx),
      );
      final sidebar = find.ancestor(
        of: find.byType(StarredChannelsSection),
        matching: find.byType(SingleChildScrollView),
      );
      expect(tester.getTopLeft(sidebar).dy, 44);
      expect(tester.getBottomLeft(sidebar).dy, 680);
      await tester.tap(find.byTooltip('Star channel'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Unstar channel'), findsOneWidget);
      expect(find.text('Starred'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Starred')).dy,
        lessThan(tester.getTopLeft(find.text('Channels')).dy),
      );
      await tester.tap(find.text('design'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome to #design'), findsOneWidget);
      expect(find.byTooltip('Star channel'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Message #design'), findsOneWidget);
      final starredGeneral = find.descendant(
        of: find.byType(StarredChannelsSection),
        matching: find.text('general'),
      );
      await tester.tap(starredGeneral);
      await tester.pumpAndSettle();
      expect(find.text('Welcome to #general'), findsOneWidget);
      expect(find.byTooltip('Unstar channel'), findsOneWidget);

      // Dispose the app's providers and restore preferences through a fresh repository.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.text('Starred'), findsOneWidget);
      expect(find.byTooltip('Unstar channel'), findsOneWidget);
      tester.view.physicalSize = const Size(1024, 600);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Unstar channel'), findsOneWidget);
      final resizeError = tester.takeException();
      expect(
        resizeError is FlutterError ? resizeError.toStringDeep() : resizeError,
        isNull,
      );
      tester.view.physicalSize = const Size(1264, 680);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Unstar channel'));
      await tester.pumpAndSettle();
      expect(find.text('Starred'), findsNothing);
      expect(find.text('general'), findsOneWidget);
      await tester.tap(find.byTooltip('Star channel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View all channels'));
      await tester.pumpAndSettle();
      expect(find.byType(ChannelDirectoryView), findsOneWidget);
      await tester.tap(find.text('general').last);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Unstar channel'), findsOneWidget);
      await tester.tap(find.text('Add channel'));
      await tester.pumpAndSettle();
      expect(find.byType(CreateChannelModal), findsOneWidget);
      await tester.enterText(
        find
            .descendant(
              of: find.byType(CreateChannelModal),
              matching: find.byType(TextField),
            )
            .first,
        'test-channel',
      );
      await tester.ensureVisible(find.text('Create'));
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not create channel.'), findsOneWidget);
      expect(find.byType(CreateChannelModal), findsOneWidget);
      _Channels.createSucceeds = true;
      await tester.ensureVisible(find.text('Create'));
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(find.byType(CreateChannelModal), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
