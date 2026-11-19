import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/auth/presentation/components/auth_header_row.dart';

Widget _host({required double width}) {
  return MaterialApp(
    home: Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        title: AuthHeaderRow(
          prompt: "Don't have an account? ",
          action: 'Sign up',
          logo: const SizedBox(width: 83, height: 31),
        ),
      ),
    ),
  );
}

void main() {
  group('AuthHeaderRow', () {
    testWidgets('does not overflow in a narrow window', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_host(width: 360));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining("Don't have an account?"), findsOneWidget);
      expect(find.textContaining('Sign up'), findsOneWidget);
    });

    testWidgets('keeps the prompt and link on one row on a wide window', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_host(width: 1200));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Sign up'), findsOneWidget);
    });
  });
}
