import 'package:zedu/core/core.dart';

import '../../../helpers/helpers.dart';

class _FakeNetworkStatusNotifier extends NetworkStatusNotifier {
  _FakeNetworkStatusNotifier([this.initial = NetworkStatus.online]);

  final NetworkStatus initial;
  int checkReachabilityCalls = 0;

  @override
  NetworkStatus build() => initial;

  @override
  Future<void> checkReachability([ReachabilityChecker? customChecker]) async {
    checkReachabilityCalls++;
  }
}

void main() {
  group('OfflineStatusIndicator', () {
    testWidgets('is hidden when network status is online', (tester) async {
      final fakeNotifier = _FakeNetworkStatusNotifier(NetworkStatus.online);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [networkStatusProvider.overrideWith(() => fakeNotifier)],
          child: buildTestMaterialApp(
            const Scaffold(body: OfflineStatusIndicator()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('offline_status_indicator')), findsNothing);
      expect(find.text('You are offline. Reconnecting...'), findsNothing);
      expect(find.byIcon(Icons.wifi_off_rounded), findsNothing);
    });

    testWidgets('appears when network status changes to offline', (
      tester,
    ) async {
      final fakeNotifier = _FakeNetworkStatusNotifier(NetworkStatus.online);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [networkStatusProvider.overrideWith(() => fakeNotifier)],
          child: buildTestMaterialApp(
            const Scaffold(body: OfflineStatusIndicator()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('offline_status_indicator')), findsNothing);

      // Trigger offline
      fakeNotifier.setOffline();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('offline_status_indicator')), findsOneWidget);
      expect(find.text('You are offline. Reconnecting...'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
      expect(find.byKey(const Key('offline_retry_button')), findsOneWidget);
    });

    testWidgets('tapping retry calls checkReachability', (tester) async {
      final fakeNotifier = _FakeNetworkStatusNotifier(NetworkStatus.offline);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [networkStatusProvider.overrideWith(() => fakeNotifier)],
          child: buildTestMaterialApp(
            const Scaffold(body: OfflineStatusIndicator()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(fakeNotifier.checkReachabilityCalls, 0);

      await tester.tap(find.byKey(const Key('offline_retry_button')));
      await tester.pumpAndSettle();

      expect(fakeNotifier.checkReachabilityCalls, 1);
    });

    testWidgets('disappears when connectivity is restored', (tester) async {
      final fakeNotifier = _FakeNetworkStatusNotifier(NetworkStatus.offline);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [networkStatusProvider.overrideWith(() => fakeNotifier)],
          child: buildTestMaterialApp(
            const Scaffold(body: OfflineStatusIndicator()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('offline_status_indicator')), findsOneWidget);

      // Restore connectivity
      fakeNotifier.setOnline();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('offline_status_indicator')), findsNothing);
      expect(find.text('You are offline. Reconnecting...'), findsNothing);
    });
  });
}
