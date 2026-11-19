import 'dart:io' show exit;

import 'package:zedu/core/core.dart';
import 'package:zedu/app/app.dart';
import 'package:zedu/core/window/window_startup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  installGlobalErrorHandlers();
  await windowManager.ensureInitialized();

  // A second launch must focus the running window, not open another one.
  final singleInstance = SingleInstance(
    onSecondLaunch: () async {
      try {
        if (await windowManager.isMinimized()) {
          await windowManager.restore();
        }
        await windowManager.show();
        await windowManager.focus();
      } catch (error) {
        debugPrint('Failed to focus the running window: $error');
      }
    },
  );
  if (!await singleInstance.ensurePrimary()) {
    exit(0);
  }

  await loadAppEnv();
  setupLocator();
  await WindowBoundsController(
    window: windowManager,
    storage: locator<SecureStorageService>(),
  ).restore();
  await locator<WindowHotkeyController>().start();
  showWindowWhenReady(windowManager);
  AppRouter.startLocation = await AppRouter.resolveStartLocation(
    locator<SecureStorageService>(),
  );

  runApp(const ProviderScope(child: App()));
}
