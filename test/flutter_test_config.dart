import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';

/// Registers the dependencies that widgets reach for through the service
/// locator, before every test in every file.
///
/// `WorkspaceNotifier.build` starts `fetchWorkspaces`, which reads
/// `locator<AppConfig>()`. Any widget test that renders something watching
/// `workspaceProvider` therefore throws `GetIt: AppConfig is not registered`
/// unless the test happens to register it, and most do not.
///
/// This runs in `setUp` rather than once per file so it survives the
/// `locator.reset()` that several suites do in `tearDown`. Registration is
/// conditional, so a test that wants its own `AppConfig` still wins.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Several suites register their own AppConfig. Without this, the default
  // below would make their `registerSingleton` throw "already registered".
  locator.allowReassignment = true;

  setUp(() {
    if (!locator.isRegistered<AppConfig>()) {
      locator.registerSingleton<AppConfig>(
        const AppConfig(
          apiBaseUrl: 'https://api.test.invalid/api/v1/',
          usesMockData: false,
        ),
      );
    }
  });

  await testMain();
}
