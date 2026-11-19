import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class FakeSecureStorageService extends Fake implements SecureStorageService {
  final _values = <String, String>{};

  @override
  Future<String?> readData(String key) async => _values[key];

  @override
  Future<void> writeData(String key, String value) async =>
      _values[key] = value;

  @override
  Future<void> deleteValue(String key) async => _values.remove(key);
}

/// An [XFile] whose size is reported only when [length] is completed, so a
/// test can unmount the composer while `addFiles` is still waiting.
///
/// The path is empty so `addFiles` skips its disk check, as it does for a
/// pasted file; that check never completes under the widget test clock.
class DelayedLengthXFile extends XFile {
  DelayedLengthXFile(this.size) : super('');

  final Completer<int> size;

  @override
  String get name => 'notes.txt';

  @override
  Future<int> length() => size.future;
}

Widget buildComposer() {
  return ProviderScope(
    overrides: [
      dmDraftStoreProvider.overrideWith(
        (ref) => DmDraftStore(
          FakeSecureStorageService(),
          userId: 'user-1',
          orgId: 'org-1',
        ),
      ),
    ],
    child: buildTestMaterialApp(
      const Scaffold(
        body: DmMessageComposer(recipientName: 'Ada', channelId: 'dm-1'),
      ),
    ),
  );
}

void main() {
  group('DmMessageComposer.addFiles', () {
    testWidgets(
      'does not call setState when unmounted before file sizes resolve',
      (tester) async {
        await tester.pumpWidget(buildComposer());
        final state = tester.state<DmMessageComposerState>(
          find.byType(DmMessageComposer),
        );

        final size = Completer<int>();
        final pending = state.addFiles([DelayedLengthXFile(size)]);

        await tester.pumpWidget(const SizedBox.shrink());
        size.complete(1024);
        await pending;
        await tester.pump();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('still attaches the file while the composer is mounted', (
      tester,
    ) async {
      await tester.pumpWidget(buildComposer());
      final state = tester.state<DmMessageComposerState>(
        find.byType(DmMessageComposer),
      );

      final size = Completer<int>();
      final pending = state.addFiles([DelayedLengthXFile(size)]);
      size.complete(1024);
      await pending;
      await tester.pump();

      expect(find.textContaining('notes.txt'), findsOneWidget);
    });
  });
}
