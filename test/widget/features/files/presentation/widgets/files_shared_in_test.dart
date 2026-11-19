import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

void main() {
  const file = WorkspaceFile(
    id: 'f-1',
    name: 'logo.png',
    fileType: 'png',
    size: 2048,
  );

  Widget table() => buildTestMaterialApp(
    Scaffold(
      body: FilesTable(
        files: const [file],
        ownerNameOf: (_) => 'Ada Lovelace',
        onOpen: (_) {},
      ),
    ),
  );

  testWidgets('shows the channels the file was shared in', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fileInfoProvider.overrideWith(
            (ref, fileId) async => const WorkspaceFileInfo(
              owner: 'Ada Lovelace',
              sharedIn: ['general', 'design'],
            ),
          ),
        ],
        child: table(),
      ),
    );
    await tester.pumpAndSettle();

    final cell = find.byKey(const ValueKey('shared-in-f-1'));
    expect(
      find.descendant(of: cell, matching: find.text('general, design')),
      findsOneWidget,
    );
  });

  testWidgets('keeps the dash when the file was shared nowhere', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fileInfoProvider.overrideWith(
            (ref, fileId) async => const WorkspaceFileInfo(),
          ),
        ],
        child: table(),
      ),
    );
    await tester.pumpAndSettle();

    final cell = find.byKey(const ValueKey('shared-in-f-1'));
    expect(find.descendant(of: cell, matching: find.text('—')), findsOneWidget);
  });
}
