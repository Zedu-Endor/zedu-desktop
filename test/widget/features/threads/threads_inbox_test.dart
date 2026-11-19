import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../helpers/test_material_app.dart';

class _State extends ThreadsInboxNotifier {
  _State(this.initial);
  final ThreadsInboxState initial;
  int refreshes = 0;
  @override
  ThreadsInboxState build() => initial;
  @override
  Future<void> refresh() async {
    refreshes++;
  }
}

Future<_State> _pump(
  WidgetTester tester,
  ThreadsInboxState state, {
  String org = 'org-1',
}) async {
  final notifier = _State(state);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentOrgIdProvider.overrideWithValue(org),
        threadsInboxProvider.overrideWith(() => notifier),
      ],
      child: buildTestMaterialApp(const Scaffold(body: ThreadsInboxBody())),
    ),
  );
  await tester.pump();
  return notifier;
}

void main() {
  testWidgets('shows a loading state instead of a false empty inbox', (
    tester,
  ) async {
    await _pump(tester, const ThreadsInboxState(loading: true));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('No threads yet'), findsNothing);
  });
  testWidgets('shows no-workspace guidance', (tester) async {
    await _pump(tester, const ThreadsInboxState(), org: '');
    expect(
      find.text('Select a workspace to see your threads.'),
      findsOneWidget,
    );
  });
  testWidgets('shows the empty state only after a successful empty response', (
    tester,
  ) async {
    await _pump(tester, const ThreadsInboxState());
    expect(find.text('No threads yet'), findsOneWidget);
  });
  testWidgets('error has retry and never claims the inbox is empty', (
    tester,
  ) async {
    final notifier = await _pump(
      tester,
      const ThreadsInboxState(
        error: 'Could not load threads. Please try again.',
      ),
    );
    expect(find.text('No threads yet'), findsNothing);
    await tester.tap(find.text('Retry'));
    expect(notifier.refreshes, 1);
  });
  testWidgets('shows unread total and opens real returned discussion content', (
    tester,
  ) async {
    await _pump(
      tester,
      const ThreadsInboxState(
        unseenCount: 3,
        threads: [
          InboxThread(
            id: 'thread-1',
            channelId: 'channel-1',
            channelName: 'engineering',
            messages: [
              InboxThreadMessage(
                threadId: 'thread-1',
                channelId: 'channel-1',
                author: 'Grace',
                content: '<p>Release &amp; deploy</p>',
              ),
            ],
          ),
        ],
      ),
    );
    expect(find.text('3 unread'), findsOneWidget);
    expect(find.text('Grace: Release & deploy'), findsOneWidget);
    expect(find.textContaining('<p>'), findsNothing);
    await tester.tap(find.text('Read discussion'));
    await tester.pumpAndSettle();
    expect(find.text('Grace\nRelease & deploy'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
  testWidgets('load-more errors keep previously loaded discussions visible', (
    tester,
  ) async {
    await _pump(
      tester,
      const ThreadsInboxState(
        error: 'Could not load threads. Please try again.',
        hasMore: true,
        threads: [
          InboxThread(
            id: 'thread-1',
            channelId: 'channel-1',
            channelName: 'engineering',
            messages: [
              InboxThreadMessage(
                threadId: 'thread-1',
                channelId: 'channel-1',
                author: 'Grace',
                content: 'Existing discussion',
              ),
            ],
          ),
        ],
      ),
    );
    expect(find.text('Grace: Existing discussion'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
