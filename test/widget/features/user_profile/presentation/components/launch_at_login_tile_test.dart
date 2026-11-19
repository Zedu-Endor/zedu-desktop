import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/test_material_app.dart';

class _FakeLaunchAtLoginService implements LaunchAtLoginService {
  _FakeLaunchAtLoginService({this.enabled = false});

  bool enabled;
  @override
  bool isSupported = true;

  @override
  Future<bool> isEnabled() async => enabled;

  @override
  Future<void> setEnabled(bool value) async {
    enabled = value;
  }
}

Switch _switch(WidgetTester tester) =>
    tester.widget<Switch>(find.byType(Switch));

/// A login item that cannot be read, e.g. the registry read fails.
class _UnreadableLaunchAtLoginService implements LaunchAtLoginService {
  @override
  bool isSupported = true;

  @override
  Future<bool> isEnabled() async => throw StateError('login item read failed');

  @override
  Future<void> setEnabled(bool value) async {}
}

void main() {
  macOsVersionTests();

  testWidgets('shows the switch off by default', (tester) async {
    await tester.pumpWidget(
      buildTestMaterialApp(
        Scaffold(body: LaunchAtLoginTile(service: _FakeLaunchAtLoginService())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Launch Zedu at login'), findsOneWidget);
    expect(_switch(tester).value, isFalse);
  });

  testWidgets('turning it on and off updates the login item', (tester) async {
    final service = _FakeLaunchAtLoginService();
    await tester.pumpWidget(
      buildTestMaterialApp(Scaffold(body: LaunchAtLoginTile(service: service))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(service.enabled, isTrue);
    expect(_switch(tester).value, isTrue);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(service.enabled, isFalse);
    expect(_switch(tester).value, isFalse);
  });

  testWidgets('shows the saved state when the screen opens', (tester) async {
    await tester.pumpWidget(
      buildTestMaterialApp(
        Scaffold(
          body: LaunchAtLoginTile(
            service: _FakeLaunchAtLoginService(enabled: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_switch(tester).value, isTrue);
  });

  testWidgets('shows nothing where there is no login item', (tester) async {
    final service = _FakeLaunchAtLoginService()..isSupported = false;
    await tester.pumpWidget(
      buildTestMaterialApp(Scaffold(body: LaunchAtLoginTile(service: service))),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('logs a failed state read and leaves the switch off', (
    tester,
  ) async {
    final logs = <String>[];
    final previousDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) logs.add(message);
    };

    try {
      await tester.pumpWidget(
        buildTestMaterialApp(
          Scaffold(
            body: LaunchAtLoginTile(service: _UnreadableLaunchAtLoginService()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Safe default: an unreadable login item leaves the switch off...
      expect(_switch(tester).value, isFalse);
      // ...and the read is finished, so the tile is no longer busy.
      expect(_switch(tester).onChanged, isNotNull);

      final failures = logs.where(
        (line) => line.contains('LaunchAtLoginTile._load:'),
      );
      expect(failures, isNotEmpty, reason: 'the failure must be logged');
      expect(
        failures.any((line) => line.contains('login item read failed')),
        isTrue,
        reason: 'the log line must carry the error itself',
      );
    } finally {
      // Restored before the binding checks the foundation debug variables.
      debugPrint = previousDebugPrint;
    }
  });
}

void macOsVersionTests() {
  group('macOsSupportsLoginItem', () {
    test('is true from macOS 13', () {
      expect(macOsSupportsLoginItem('Version 13.0 (Build 22A380)'), isTrue);
      expect(macOsSupportsLoginItem('Version 14.5 (Build 23F79)'), isTrue);
    });

    test('is false before macOS 13 or when it cannot be read', () {
      expect(macOsSupportsLoginItem('Version 12.7 (Build 21H1015)'), isFalse);
      expect(macOsSupportsLoginItem('Version 10.15.7 (Build 19H2)'), isFalse);
      expect(macOsSupportsLoginItem('unknown'), isFalse);
    });
  });
}
