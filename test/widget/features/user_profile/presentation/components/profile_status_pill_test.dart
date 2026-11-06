import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/test_material_app.dart';

void main() {
  group('ProfileStatusPill', () {
    testWidgets('renders active status with capitalization', (tester) async {
      await tester.pumpWidget(
        buildTestMaterialApp(const ProfileStatusPill(status: 'active')),
      );

      expect(find.text('Active'), findsOneWidget);
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(ProfileStatusPill),
          matching: find.byType(Container).first,
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFFECFDF5));
    });

    testWidgets('renders pending status with neutral amber styling', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestMaterialApp(const ProfileStatusPill(status: 'pending')),
      );

      expect(find.text('Pending'), findsOneWidget);
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(ProfileStatusPill),
          matching: find.byType(Container).first,
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFFFFF7ED));
    });

    testWidgets('renders non-active status with capitalization', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestMaterialApp(const ProfileStatusPill(status: 'inactive')),
      );

      expect(find.text('Inactive'), findsOneWidget);
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(ProfileStatusPill),
          matching: find.byType(Container).first,
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFFFEF2F2));
    });

    testWidgets('handles empty status string without throwing RangeError', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestMaterialApp(const ProfileStatusPill(status: '')),
      );

      expect(find.text('Unknown'), findsOneWidget);
    });

    testWidgets('handles whitespace-only status string gracefully', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestMaterialApp(const ProfileStatusPill(status: '   ')),
      );

      expect(find.text('Unknown'), findsOneWidget);
    });
  });
}
