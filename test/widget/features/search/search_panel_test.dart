import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../helpers/helpers.dart';

class _FakeSearchNotifier extends SearchNotifier {
  _FakeSearchNotifier(this.initialState);

  final SearchState initialState;

  @override
  SearchState build() => initialState;
}

const _result = SearchResult(
  user: SearchUser(
    userId: 'user-1',
    userName: 'Ada Lovelace',
    avatarUrl: '',
    defaultAvatarUrl: '',
    isDeactivated: false,
  ),
  messages: [
    SearchMessage(
      messageId: 'message-1',
      threadId: 'thread-1',
      text: 'the release is on friday',
      timestamp: '2026-10-21T10:00:00Z',
    ),
  ],
  channel: SearchChannel(
    channelId: 'channel-1',
    channelName: 'general',
    channelType: 'channel',
  ),
);

void main() {
  Future<void> pumpPanel(
    WidgetTester tester,
    SearchState state, {
    void Function(SearchResult)? onResultSelected,
    VoidCallback? onClose,
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchNotifierProvider.overrideWith(
            () => _FakeSearchNotifier(state),
          ),
        ],
        child: buildTestMaterialApp(
          Scaffold(
            body: Row(
              children: [
                SizedBox(
                  width: 320,
                  child: SearchPanel(
                    onClose: onClose ?? () {},
                    onResultSelected: onResultSelected,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    // A loading spinner never settles, so those cases only pump one frame.
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  testWidgets('prompts for a term before anything is searched', (tester) async {
    await pumpPanel(tester, const SearchState());

    expect(find.text('Enter a search term'), findsOneWidget);
  });

  testWidgets('shows a spinner while the search is running', (tester) async {
    await pumpPanel(
      tester,
      const SearchState(status: SearchStatus.loading, query: 'release'),
      settle: false,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('reports a failed search instead of staying empty', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      const SearchState(
        status: SearchStatus.error,
        query: 'release',
        error: 'Search failed. Please try again.',
      ),
    );

    expect(find.text('Search failed. Please try again.'), findsOneWidget);
  });

  testWidgets('says so when the search returned nothing', (tester) async {
    await pumpPanel(
      tester,
      const SearchState(status: SearchStatus.ready, query: 'release'),
    );

    expect(find.text('No results found'), findsOneWidget);
  });

  testWidgets('renders the hits that came back from the backend', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      const SearchState(
        status: SearchStatus.ready,
        query: 'release',
        results: [_result],
      ),
    );

    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('the release is on friday'), findsOneWidget);
  });

  testWidgets('hands the picked hit back to the caller', (tester) async {
    SearchResult? picked;

    await pumpPanel(
      tester,
      const SearchState(
        status: SearchStatus.ready,
        query: 'release',
        results: [_result],
      ),
      onResultSelected: (result) => picked = result,
    );

    await tester.tap(find.byKey(const Key('search_result_channel-1')));
    await tester.pumpAndSettle();

    expect(picked, isNotNull);
    expect(picked!.channel.channelId, 'channel-1');
  });
}
