import 'package:zedu/features/features.dart';

/// Whether a desktop pop-up for a direct message may be shown now.
///
/// Applies the saved Settings > Notifications preferences and the
/// "Pause notifications" option of the current status:
/// - [NotificationMode.none] ("Nothing") never shows a pop-up.
/// - [NotificationMode.mentionsOnly] covers "messages you directly", so a
///   direct message still shows.
/// - Quiet hours hide pop-ups between their pause and resume times.
/// - A status with "Pause notifications" hides pop-ups until it expires.
///
/// Null [preferences] (not loaded yet, or failed to load) fall back to the
/// default, which shows everything.
bool desktopNotificationAllowed({
  required NotificationPreferences? preferences,
  required UserStatus? status,
  required DateTime now,
}) {
  if (status != null && status.pauseNotifications && !status.isExpired) {
    return false;
  }
  if (preferences == null) return true;
  if (preferences.mode == NotificationMode.none) return false;
  if (preferences.quietHoursEnabled && _inQuietHours(preferences, now)) {
    return false;
  }
  return true;
}

/// Quiet hours are minutes after midnight. A period whose resume time is at or
/// before its pause time wraps past midnight, e.g. 10:00 PM to 7:00 AM.
bool _inQuietHours(NotificationPreferences preferences, DateTime now) {
  if (!preferences.hasValidQuietHours) return false;
  final minute = now.hour * 60 + now.minute;
  final from = preferences.pauseFrom;
  final to = preferences.resumeAt;
  if (preferences.quietHoursCrossMidnight) {
    return minute >= from || minute < to;
  }
  return minute >= from && minute < to;
}
