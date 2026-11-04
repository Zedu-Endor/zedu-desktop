import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class _FakeUserProfileNotifier extends UserProfileNotifier {
  @override
  UserProfileState build() => const UserProfileState();
}

// The page also suggests channels, so keep this test off the real network.
class _FakeChannelNotifier extends ChannelNotifier {
  @override
  Future<List<Channel>> build() async => const [];
}

void main() {
  testWidgets('labels the page New message and the recipients To', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileNotifierProvider.overrideWith(
            _FakeUserProfileNotifier.new,
          ),
          channelProvider.overrideWith(_FakeChannelNotifier.new),
        ],
        child: buildTestMaterialApp(const Scaffold(body: NewGroupChatView())),
      ),
    );
    await tester.pump();

    expect(find.text('New message'), findsOneWidget);
    expect(find.text('To: '), findsOneWidget);
    expect(find.text('New Group Chat'), findsNothing);
    expect(find.text('With: '), findsNothing);
  });
}
