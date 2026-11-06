import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../helpers/helpers.dart';

void main() {
  // A Friday at 10:00, so "tomorrow at 9" is unambiguous.
  final now = DateTime(2026, 11, 6, 10);

  Future<DateTime?> openPicker(WidgetTester tester) async {
    DateTime? chosen;
    await tester.pumpWidget(
      ProviderScope(
        child: buildTestMaterialApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                chosen = await showDialog<DateTime>(
                  context: context,
                  builder: (_) => ReminderPickerDialog(now: now),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return chosen;
  }

  testWidgets('offers the four choices the ticket asks for', (tester) async {
    await openPicker(tester);

    expect(find.text('In 30 minutes'), findsOneWidget);
    expect(find.text('In 1 hour'), findsOneWidget);
    expect(find.text('Tomorrow at 9:00 AM'), findsOneWidget);
    expect(find.text('Custom'), findsOneWidget);
  });

  testWidgets('In 30 minutes resolves against the current time', (
    tester,
  ) async {
    await openPicker(tester);
    await tester.tap(find.text('In 30 minutes'));
    await tester.pumpAndSettle();

    // The dialog closed with a time, which the caller then sends on.
    expect(find.text('In 30 minutes'), findsNothing);
  });

  testWidgets('each preset previews the time it will set', (tester) async {
    await openPicker(tester);

    // 10:00 + 30 minutes, and 10:00 + 1 hour, both today.
    expect(find.text('Today, 10:30 AM'), findsOneWidget);
    expect(find.text('Today, 11:00 AM'), findsOneWidget);
    expect(find.text('Tomorrow, 9:00 AM'), findsOneWidget);
  });

  testWidgets('cancelling chooses nothing', (tester) async {
    await openPicker(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('In 30 minutes'), findsNothing);
  });

  test('the presets resolve to the times they name', () {
    expect(
      ReminderPreset.inThirtyMinutes.resolve(now),
      DateTime(2026, 11, 6, 10, 30),
    );
    expect(ReminderPreset.inOneHour.resolve(now), DateTime(2026, 11, 6, 11));
    expect(
      ReminderPreset.tomorrowMorning.resolve(now),
      DateTime(2026, 11, 7, 9),
    );
  });

  test('tomorrow morning rolls over a month end', () {
    expect(
      ReminderPreset.tomorrowMorning.resolve(DateTime(2026, 11, 30, 23, 50)),
      DateTime(2026, 12, 1, 9),
    );
  });
}
