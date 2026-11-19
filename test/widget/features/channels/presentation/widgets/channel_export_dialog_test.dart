import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

final _channel = Channel(
  id: 'channel-1',
  name: 'general',
  description: '',
  organisationId: 'org-1',
  ownerId: 'user-1',
);

ChannelExport _export(
  ChannelExportStatus status, {
  String? url,
  String? error,
}) =>
    ChannelExport(id: 'e1', status: status, fileUrl: url, errorMessage: error);

/// Answers the start call, then each status check, from the given lists.
class _ExportRepository extends Mock implements ChannelRepository {
  _ExportRepository({required this.starts, this.statuses = const []});

  final List<Result<ChannelExport>> starts;
  final List<Result<ChannelExport>> statuses;
  int startCalls = 0;
  int statusCalls = 0;

  @override
  Future<Result<ChannelExport>> startChannelExport(String channelId) async =>
      starts[startCalls++];

  @override
  Future<Result<ChannelExport>> fetchChannelExportStatus(
    String channelId,
  ) async => statuses[statusCalls++];
}

Future<List<Uri>> _pump(
  WidgetTester tester,
  _ExportRepository repository, {
  bool launchWorks = true,
}) async {
  final launched = <Uri>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [channelRepositoryProvider.overrideWithValue(repository)],
      child: buildTestMaterialApp(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => ChannelExportDialog(
                  channel: _channel,
                  pollInterval: const Duration(seconds: 1),
                  maxWait: const Duration(seconds: 10),
                  launcher: (url) async {
                    launched.add(url);
                    return launchWorks;
                  },
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pump();
  await tester.pump();
  return launched;
}

void main() {
  group('ChannelExport.fromJson', () {
    test('reads each status and the file url', () {
      expect(
        ChannelExport.fromJson({'id': 'e1', 'status': 'pending'}).status,
        ChannelExportStatus.pending,
      );
      expect(
        ChannelExport.fromJson({'status': 'in_progress'}).isRunning,
        isTrue,
      );
      final done = ChannelExport.fromJson({
        'status': 'completed',
        'file_url': 'https://files.zedu.chat/e1.zip',
      });
      expect(done.status, ChannelExportStatus.completed);
      expect(done.fileUrl, 'https://files.zedu.chat/e1.zip');
      expect(
        ChannelExport.fromJson({
          'status': 'failed',
          'error_message': 'Too large',
        }).errorMessage,
        'Too large',
      );
    });
  });

  group('ChannelExportDialog (Ziki #2629)', () {
    testWidgets('waits for the export, then downloads the file', (
      tester,
    ) async {
      final repository = _ExportRepository(
        starts: [Success(_export(ChannelExportStatus.pending))],
        statuses: [
          Success(_export(ChannelExportStatus.inProgress)),
          Success(
            _export(
              ChannelExportStatus.completed,
              url: 'https://files.zedu.chat/e1.zip',
            ),
          ),
        ],
      );
      final launched = await _pump(tester, repository);

      expect(find.text('Preparing your export of #general…'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.text('Download'), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(find.text('Your export of #general is ready.'), findsOneWidget);
      expect(repository.statusCalls, 2);
      await tester.tap(find.text('Download'));
      await tester.pumpAndSettle();

      expect(launched, [Uri.parse('https://files.zedu.chat/e1.zip')]);
      expect(find.byType(ChannelExportDialog), findsNothing);
    });

    testWidgets('a failed export shows why, and Try again starts over', (
      tester,
    ) async {
      final repository = _ExportRepository(
        starts: [
          Success(
            _export(
              ChannelExportStatus.failed,
              error: 'Export failed: timeout',
            ),
          ),
          Success(
            _export(
              ChannelExportStatus.completed,
              url: 'https://files.zedu.chat/e2.zip',
            ),
          ),
        ],
      );
      await _pump(tester, repository);

      expect(find.text('Export failed: timeout'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump();

      expect(repository.startCalls, 2);
      expect(find.text('Download'), findsOneWidget);
    });

    testWidgets('a request error is shown with Try again', (tester) async {
      final repository = _ExportRepository(
        starts: [
          const Failure(
            ApiFailure(message: 'user is not a member of this channel'),
          ),
        ],
      );
      await _pump(tester, repository);

      expect(find.text('user is not a member of this channel'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('gives up after the time limit', (tester) async {
      final running = Success(_export(ChannelExportStatus.inProgress));
      final repository = _ExportRepository(
        starts: [running],
        statuses: List.filled(20, running),
      );
      await _pump(tester, repository);

      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      expect(
        find.text(
          'The export is taking longer than expected. Try again later.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('closing the dialog stops checking', (tester) async {
      final running = Success(_export(ChannelExportStatus.inProgress));
      final repository = _ExportRepository(
        starts: [running],
        statuses: List.filled(20, running),
      );
      await _pump(tester, repository);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      final callsAtClose = repository.statusCalls;
      await tester.pump(const Duration(seconds: 5));

      expect(repository.statusCalls, callsAtClose);
    });
  });
}
