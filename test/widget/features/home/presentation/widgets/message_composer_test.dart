import "package:file_picker/src/platform/file_picker_platform_interface.dart";
import "package:zedu/core/core.dart";
import "package:zedu/features/features.dart";

import "../../../../../helpers/helpers.dart";

const _recordChannel = MethodChannel("com.llfbandit.record/messages");

class FakeUserProfileNotifier extends UserProfileNotifier {
  @override
  UserProfileState build() => const UserProfileState();
}

class FakeFilePickerPlatform extends FilePickerPlatform {
  FilePickerResult? resultToReturn;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    void Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
    bool cancelUploadOnWindowBlur = true,
  }) async {
    return resultToReturn;
  }
}

Future<void> _pumpComposer(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userProfileNotifierProvider.overrideWith(FakeUserProfileNotifier.new),
      ],
      child: buildTestMaterialApp(
        Scaffold(
          body: MessageComposer(
            activeChat: ActiveChatState.generalChannel,
            onSend: (_) {},
          ),
        ),
      ),
    ),
  );
}

Widget _buildComposer({required ValueChanged<String> onSend}) {
  return ProviderScope(
    overrides: [
      userProfileNotifierProvider.overrideWith(FakeUserProfileNotifier.new),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: MessageComposer(
          activeChat: ActiveChatState.generalChannel,
          onSend: onSend,
        ),
      ),
    ),
  );
}

void main() {
  late FakeFilePickerPlatform fakeFilePicker;
  late FilePickerPlatform initialPlatform;

  setUp(() {
    initialPlatform = FilePickerPlatform.instance;
    fakeFilePicker = FakeFilePickerPlatform();
    FilePickerPlatform.instance = fakeFilePicker;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_recordChannel, (call) async {
          return call.method == "hasPermission" ? true : null;
        });
  });

  tearDown(() {
    FilePickerPlatform.instance = initialPlatform;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_recordChannel, null);
  });

  testWidgets("the send button has a tooltip once there is text", (
    tester,
  ) async {
    await _pumpComposer(tester);

    // The formatting bar shows on focus, and its buttons insert text, which
    // swaps the mic for the send icon.
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.tap(find.byTooltip("Bold"));
    await tester.pumpAndSettle();

    final sendButton = find.ancestor(
      of: find.byIcon(Icons.send),
      matching: find.byType(IconButton),
    );
    expect(tester.widget<IconButton>(sendButton).tooltip, "Send message");
  });

  testWidgets("the stop button has a tooltip while recording", (tester) async {
    await _pumpComposer(tester);

    await tester.tap(find.byTooltip("Record voice note"));
    await tester.pumpAndSettle();

    final stopButton = find.ancestor(
      of: find.byIcon(Icons.stop_circle),
      matching: find.byType(IconButton),
    );
    expect(tester.widget<IconButton>(stopButton).tooltip, "Stop recording");
  });

  group("MessageComposer send button with attachments (#1570)", () {
    testWidgets(
      "shows microphone icon when text and attachments are both empty",
      (tester) async {
        await tester.pumpWidget(_buildComposer(onSend: (_) {}));

        expect(find.byIcon(Icons.mic_none), findsOneWidget);
        expect(find.byIcon(Icons.send), findsNothing);
      },
    );

    testWidgets(
      "shows Send button instead of microphone when files are attached without text",
      (tester) async {
        String sentMessage = "";
        fakeFilePicker.resultToReturn = FilePickerResult([
          PlatformFile(name: "design_specs.pdf", size: 2048),
        ]);

        await tester.pumpWidget(
          _buildComposer(
            onSend: (msg) {
              sentMessage = msg;
            },
          ),
        );

        // Initially microphone is visible
        expect(find.byIcon(Icons.mic_none), findsOneWidget);
        expect(find.byIcon(Icons.send), findsNothing);

        // Tap the attach file button
        await tester.tap(find.byTooltip("Attach file"));
        await tester.pumpAndSettle();

        // Send button should now be visible, mic hidden
        expect(find.byIcon(Icons.send), findsOneWidget);
        expect(find.byIcon(Icons.mic_none), findsNothing);

        // Attached file chip should be visible
        expect(find.text("design_specs.pdf"), findsOneWidget);

        // Tap send button
        await tester.tap(find.byIcon(Icons.send));
        await tester.pumpAndSettle();

        // Message should be sent with attachment formatting
        expect(sentMessage, "[Attachment: design_specs.pdf]");

        // Attachments cleared, mic button restored
        expect(find.byIcon(Icons.mic_none), findsOneWidget);
        expect(find.byIcon(Icons.send), findsNothing);
      },
    );

    testWidgets("shows Send button when text is typed without attachments", (
      tester,
    ) async {
      String sentMessage = "";
      await tester.pumpWidget(
        _buildComposer(
          onSend: (msg) {
            sentMessage = msg;
          },
        ),
      );

      await tester.showKeyboard(find.byType(TextField));
      await tester.enterText(find.byType(TextField), "Hello world");
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.send), findsOneWidget);
      expect(find.byIcon(Icons.mic_none), findsNothing);

      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(sentMessage, "Hello world");
      expect(find.byIcon(Icons.mic_none), findsOneWidget);
      expect(find.byIcon(Icons.send), findsNothing);
    });
  });
}
