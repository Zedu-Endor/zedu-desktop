import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../../helpers/helpers.dart';

class _MockWindowManager extends Mock implements WindowManager {}

class _MockStorage extends Mock implements SecureStorageService {}

class _FakeRegistrar implements SystemHotkeyRegistrar {
  var failRegister = false;

  @override
  Future<void> register(
    HotKey hotKey, {
    required void Function() onPressed,
  }) async {
    if (failRegister) throw Exception('already registered');
  }

  @override
  Future<void> unregister(HotKey hotKey) async {}
}

void main() {
  late _FakeRegistrar registrar;
  late WindowHotkeyController controller;

  setUp(() {
    registrar = _FakeRegistrar();
    final storage = _MockStorage();
    when(() => storage.readData(any())).thenAnswer((_) async => null);
    when(() => storage.writeData(any(), any())).thenAnswer((_) async {});
    controller = WindowHotkeyController(
      window: _MockWindowManager(),
      storage: storage,
      registrar: registrar,
      defaultBinding: HotkeyBinding.defaultFor(TargetPlatform.linux),
    );
  });

  tearDown(() => controller.dispose());

  Widget buildSection() => buildTestMaterialApp(
    Scaffold(body: DesktopSection(controller: controller)),
  );

  testWidgets('shows the current shortcut', (tester) async {
    await controller.start();
    await tester.pumpWidget(buildSection());

    expect(find.text('Show or hide Zedu'), findsOneWidget);
    expect(find.text('Ctrl + Shift + Z'), findsOneWidget);
    expect(find.text('Change'), findsOneWidget);
  });

  testWidgets('opens the recorder and cancels without changing the shortcut', (
    tester,
  ) async {
    await controller.start();
    await tester.pumpWidget(buildSection());

    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();

    expect(find.text('Record a shortcut'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Record a shortcut'), findsNothing);
    expect(find.text('Ctrl + Shift + Z'), findsOneWidget);
  });

  testWidgets('shows the registration error', (tester) async {
    registrar.failRegister = true;
    await controller.start();
    await tester.pumpWidget(buildSection());

    expect(
      find.text('That shortcut is already used by another app.'),
      findsOneWidget,
    );
  });
}
