// lib/utils/constants.dart

class AppConstants {
  static const String appName = 'ACHC Hub';
  static const String appVersion = '1.0.0';

  // Firestore Collections
  static const String usersCollection = 'users';
  static const String familiesCollection = 'families';
  static const String assignmentsCollection = 'assignments';
  static const String eventsCollection = 'events';
  static const String photosCollection = 'photos';
  static const String albumsCollection = 'albums';
  static const String feedsCollection = 'feeds';
  static const String checkInsCollection = 'checkins';
  static const String filesCollection = 'files';
  static const String chatRoomsCollection = 'chatRooms';
  static const String notificationsCollection = 'notifications';

  // SharedPreferences Keys
  static const String prefUserRole = 'user_role';
  static const String prefFamilyId = 'family_id';
  static const String prefMoodleUrl = 'moodle_url';
  static const String prefMoodleToken = 'moodle_token';
  static const String prefThemeMode = 'theme_mode';
  static const String prefLastSync = 'last_sync';

  // Default Moodle URL (placeholder)
  static const String defaultMoodleUrl = 'https://your-moodle-site.com';
}
