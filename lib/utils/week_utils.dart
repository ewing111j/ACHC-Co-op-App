// lib/utils/week_utils.dart
// ISO week helpers for ACHC Hub dashboard features.

class WeekUtils {
  WeekUtils._();

  /// Returns the Monday of the week containing [d].
  static DateTime weekStart(DateTime d) {
    final monday = d.subtract(Duration(days: d.weekday - 1));
    return DateTime(monday.year, monday.month, monday.day);
  }

  /// Returns the Sunday (end) of the week containing [d].
  static DateTime weekEnd(DateTime d) => weekStart(d).add(const Duration(days: 6));

  /// Returns an ISO week ID string, e.g. "2025-W04".
  static String weekId(DateTime d) {
    final start = weekStart(d);
    // ISO week number calculation
    final dayOfYear = int.parse(
        _dayOfYear(start).toString().padLeft(3, '0'));
    // Approximate: use the week number from the date
    final weekNum = ((dayOfYear - start.weekday + 10) ~/ 7);
    final displayWeek = weekNum < 1 ? 1 : (weekNum > 52 ? 52 : weekNum);
    return '${start.year}-W${displayWeek.toString().padLeft(2, '0')}';
  }

  static int _dayOfYear(DateTime d) {
    return d.difference(DateTime(d.year, 1, 1)).inDays + 1;
  }

  /// Returns a human-friendly week label, e.g. "Jan 6 – Jan 12".
  static String weekLabel(DateTime d) {
    final start = weekStart(d);
    final end = weekEnd(d);
    final months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    if (start.month == end.month) {
      return '${months[start.month]} ${start.day} – ${end.day}';
    }
    return '${months[start.month]} ${start.day} – ${months[end.month]} ${end.day}';
  }

  /// Returns the week one week before [d]'s week.
  static DateTime prevWeek(DateTime d) =>
      weekStart(d).subtract(const Duration(days: 7));

  /// Returns the week one week after [d]'s week.
  static DateTime nextWeek(DateTime d) =>
      weekStart(d).add(const Duration(days: 7));

  /// True if [d] falls in the same ISO week as [reference].
  static bool isSameWeek(DateTime d, DateTime reference) =>
      weekId(d) == weekId(reference);

  /// True if the week containing [d] is the current week.
  static bool isCurrentWeek(DateTime d) => isSameWeek(d, DateTime.now());
}
