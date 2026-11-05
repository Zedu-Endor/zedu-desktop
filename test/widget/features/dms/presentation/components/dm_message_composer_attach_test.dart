import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

class FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

class MockSecureStorageService extends Mock implements SecureStorageService {}

const _filePickerChannel = MethodChannel(
  'miguelruivo.flutter.plugins.filepicker',
);

Widget buildComposerUnderTest() {
  final storage = MockSecureStorageService();
  when(() => storage.readData(any())).thenAnswer((_) async => null);
  return ProviderScope(
    overrides: [
      authNotifierProvider.overrideWith(FakeAuthNotifier.new),
      dmDraftStoreProvider.overrideWith(
        (ref) => DmDraftStore(storage, userId: 'u', orgId: 'o'),
      ),
    ],
    child: buildTestMaterialApp(
      const Scaffold(
        body: DmMessageComposer(recipientName: 'Ada', channelId: 'channel-1'),
      ),
    ),
  );
}

// The composer's voice recorder talks to this channel once real async work
// runs; the test has no recorder, so it answers nothing.
const _recordChannel = MethodChannel('com.llfbandit.record/messages');

/// Makes the system file dialog return [paths], as it does on macOS and Linux.
void fakeFilePicker(WidgetTester tester, List<String> paths) {
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    _filePickerChannel,
    (call) async => [
      for (final path in paths)
        {'path': path, 'name': path.split('/').last, 'size': 1024},
    ],
  );
  messenger.setMockMethodCallHandler(_recordChannel, (call) async => null);
  addTearDown(() {
    messenger.setMockMethodCallHandler(_filePickerChannel, null);
    messenger.setMockMethodCallHandler(_recordChannel, null);
  });
}

void main() {
  group('DmMessageComposer Attach file', () {
    testWidgets('attaches files picked from absolute macOS and Linux paths', (
      tester,
    ) async {
      fakeFilePicker(tester, [
        '/tmp/report.pdf',
        '/home/ada/Documents/notes..v2.txt',
      ]);
      await tester.pumpWidget(buildComposerUnderTest());

      // Checking each file's size reads the disk, which needs real time.
      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('Attach file'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      final pending = tester
          .state<DmMessageComposerState>(find.byType(DmMessageComposer))
          .pendingFiles;
      expect(pending.map((f) => f.path), [
        '/tmp/report.pdf',
        '/home/ada/Documents/notes..v2.txt',
      ]);
      expect(find.textContaining('report.pdf'), findsOneWidget);
      expect(find.textContaining('notes..v2.txt'), findsOneWidget);
      expect(find.textContaining('Invalid file path'), findsNothing);
    });

    testWidgets('does not use the bare extension as the MIME type', (
      tester,
    ) async {
      fakeFilePicker(tester, ['/tmp/report.pdf']);
      await tester.pumpWidget(buildComposerUnderTest());

      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('Attach file'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      final pending = tester
          .state<DmMessageComposerState>(find.byType(DmMessageComposer))
          .pendingFiles;
      expect(pending, hasLength(1));
      expect(pending.single.mimeType, isNot('pdf'));
    });
  });
}
