/// Same-day ordering cutoff policy.
///
/// The app applies a soft nudge at 4 PM Cairo time (UTC+2, no DST).
/// After the cutoff, same-day orders trigger a confirmation dialog
/// offering to schedule for tomorrow, but the customer can still
/// proceed if they choose.
///
/// Egypt observes UTC+2 year-round (no DST since 2014), so a fixed
/// offset is safe.
library;

const int cairoSameDayCutoffHour = 16; // 4 PM

/// Current time in Cairo (UTC+2).
DateTime cairoNow() => DateTime.now().toUtc().add(const Duration(hours: 2));

/// True if Cairo's current hour is at or past the same-day cutoff.
bool isAfterCairoCutoff() => cairoNow().hour >= cairoSameDayCutoffHour;

/// True if [scheduledTime] (a DateTime in any zone) falls on today's
/// date in Cairo.
bool isSameDayInCairo(DateTime scheduledTime) {
  final scheduledCairo =
      scheduledTime.toUtc().add(const Duration(hours: 2));
  final nowCairo = cairoNow();
  return scheduledCairo.year == nowCairo.year &&
      scheduledCairo.month == nowCairo.month &&
      scheduledCairo.day == nowCairo.day;
}

/// True if a submit should trigger the same-day soft nudge.
///
/// A submit triggers the nudge when ALL of these hold:
///   - It is past the Cairo cutoff (isAfterCairoCutoff())
///   - The order is same-day, meaning either:
///       a) urgencyType == 'urgent' (no scheduledTime), OR
///       b) urgencyType == 'scheduled' and scheduledTime is today in Cairo
bool shouldShowSameDayNudge({
  required String urgencyType,
  DateTime? scheduledTime,
}) {
  if (!isAfterCairoCutoff()) return false;
  if (urgencyType == 'urgent') return true;
  if (urgencyType == 'scheduled' &&
      scheduledTime != null &&
      isSameDayInCairo(scheduledTime)) {
    return true;
  }
  return false;
}
