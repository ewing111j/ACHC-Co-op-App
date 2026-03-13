// lib/services/notification_prefs_service.dart
// Manages user notification badge preferences stored in SharedPreferences
import 'package:shared_preferences/shared_preferences.dart';

class NotificationPrefsService {
  static const _prefix = 'notif_badge_';

  // Keys for each section
  static const String keyAssignments = '${_prefix}assignments';
  static const String keyMessages = '${_prefix}messages';
  static const String keyCalendar = '${_prefix}calendar';
  static const String keyFiles = '${_prefix}files';
  static const String keyFeedAnnouncements = '${_prefix}feed_announcements';
  static const String keyFeedSocial = '${_prefix}feed_social';
  static const String keyFeedPrayer = '${_prefix}feed_prayer';
  static const String keyPhotos = '${_prefix}photos';

  // Announcements cannot be turned off - always true
  static const List<String> alwaysOn = [keyFeedAnnouncements];

  static Future<Map<String, bool>> loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      keyAssignments: prefs.getBool(keyAssignments) ?? true,
      keyMessages: prefs.getBool(keyMessages) ?? true,
      keyCalendar: prefs.getBool(keyCalendar) ?? true,
      keyFiles: prefs.getBool(keyFiles) ?? true,
      keyFeedAnnouncements: true, // always on
      keyFeedSocial: prefs.getBool(keyFeedSocial) ?? true,
      keyFeedPrayer: prefs.getBool(keyFeedPrayer) ?? true,
      keyPhotos: prefs.getBool(keyPhotos) ?? false,
    };
  }

  static Future<void> setPref(String key, bool value) async {
    if (alwaysOn.contains(key)) return; // Cannot disable announcements
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }
}
