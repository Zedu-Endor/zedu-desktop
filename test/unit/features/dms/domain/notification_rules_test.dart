import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

void main() {
  final base = NotificationPreferences.empty();
  final noon = DateTime(2026, 11, 3, 12);

  bool allowed({
    NotificationPreferences? preferences,
    UserStatus? status,
    DateTime? now,
  }) => desktopNotificationAllowed(
    preferences: preferences,
    status: status,
    now: now ?? noon,
  );

  group('desktopNotificationAllowed', () {
    test('shows pop-ups when preferences are not loaded yet', () {
      expect(allowed(), isTrue);
    });

    test('shows pop-ups for "All new messages"', () {
      expect(allowed(preferences: base), isTrue);
    });

    test('never shows pop-ups for "Nothing"', () {
      expect(
        allowed(preferences: base.copyWith(mode: NotificationMode.none)),
        isFalse,
      );
    });

    test('still shows direct messages for "Mentions"', () {
      expect(
        allowed(
          preferences: base.copyWith(mode: NotificationMode.mentionsOnly),
        ),
        isTrue,
      );
    });

    group('quiet hours', () {
      // 10:00 PM to 7:00 AM, wrapping past midnight.
      final overnight = base.copyWith(
        quietHoursEnabled: true,
        pauseFrom: 22 * 60,
        resumeAt: 7 * 60,
      );
      // 1:00 PM to 2:00 PM, within one day.
      final lunch = base.copyWith(
        quietHoursEnabled: true,
        pauseFrom: 13 * 60,
        resumeAt: 14 * 60,
      );

      test('hide pop-ups inside an overnight period', () {
        expect(
          allowed(preferences: overnight, now: DateTime(2026, 11, 3, 23)),
          isFalse,
        );
        expect(
          allowed(preferences: overnight, now: DateTime(2026, 11, 4, 6, 59)),
          isFalse,
        );
      });

      test('show pop-ups outside an overnight period', () {
        expect(
          allowed(preferences: overnight, now: DateTime(2026, 11, 4, 7)),
          isTrue,
        );
        expect(allowed(preferences: overnight), isTrue);
      });

      test('hide pop-ups inside a same-day period only', () {
        expect(
          allowed(preferences: lunch, now: DateTime(2026, 11, 3, 13, 30)),
          isFalse,
        );
        expect(
          allowed(preferences: lunch, now: DateTime(2026, 11, 3, 14)),
          isTrue,
        );
        expect(allowed(preferences: lunch), isTrue);
      });

      test('are ignored while switched off', () {
        final off = overnight.copyWith(quietHoursEnabled: false);
        expect(
          allowed(preferences: off, now: DateTime(2026, 11, 3, 23)),
          isTrue,
        );
      });
    });

    group('status "Pause notifications"', () {
      test('hides pop-ups while the status is active', () {
        expect(
          allowed(
            preferences: base,
            status: UserStatus(
              text: 'Vacationing',
              pauseNotifications: true,
              expiresAt: DateTime.now().add(const Duration(hours: 1)),
            ),
          ),
          isFalse,
        );
      });

      test('hides pop-ups for a status that never expires', () {
        expect(
          allowed(
            status: const UserStatus(
              text: 'Focusing',
              pauseNotifications: true,
            ),
          ),
          isFalse,
        );
      });

      test('shows pop-ups again once the status has expired', () {
        expect(
          allowed(
            preferences: base,
            status: UserStatus(
              text: 'In a meeting',
              pauseNotifications: true,
              expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
            ),
          ),
          isTrue,
        );
      });

      test('does nothing when the status does not pause notifications', () {
        expect(
          allowed(
            preferences: base,
            status: const UserStatus(text: 'Working remotely'),
          ),
          isTrue,
        );
      });
    });
  });
}
