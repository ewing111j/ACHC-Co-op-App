// lib/screens/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/notification_prefs_service.dart';
import '../assignments/assignments_screen.dart';
import '../messages/messages_screen.dart';
import '../calendar/calendar_screen.dart';
import '../checkin/checkin_screen.dart';
import '../files/files_screen.dart';
import '../feeds/feeds_screen.dart';
import '../settings/settings_screen.dart';
import '../admin/admin_screen.dart';
import '../classes/classes_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = FirebaseFirestore.instance;
  Map<String, bool> _notifPrefs = {};
  String? _coopWeekLabel;
  // Track "last seen" timestamps per section to show badge when new content arrives
  Map<String, int> _lastSeenTs = {};

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadCoopWeekLabel();
    _loadLastSeenTs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await NotificationPrefsService.loadPrefs();
    if (mounted) setState(() => _notifPrefs = prefs);
  }

  Future<void> _loadCoopWeekLabel() async {
    try {
      final weekKey = _currentWeekKey();
      final doc = await _db.collection('coopCalendar').doc(weekKey).get();
      if (mounted && doc.exists) {
        setState(() => _coopWeekLabel = doc.data()?['label'] as String?);
      }
    } catch (_) {}
  }

  Future<void> _loadLastSeenTs() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = [
      'lastseen_assignments', 'lastseen_messages', 'lastseen_calendar',
      'lastseen_photos', 'lastseen_files', 'lastseen_feeds',
    ];
    final map = <String, int>{};
    for (final k in keys) {
      map[k] = prefs.getInt(k) ?? 0;
    }
    if (mounted) setState(() => _lastSeenTs = map);
  }

  Future<void> _markSeen(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final ts = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt('lastseen_$key', ts);
    if (mounted) setState(() => _lastSeenTs['lastseen_$key'] = ts);
  }

  Future<void> _clearBadge(String key) async {
    await _markSeen(key);
  }

  String _currentWeekKey() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return DateFormat('yyyy-MM-dd').format(monday);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          _buildHeader(context, user, auth),
          SliverToBoxAdapter(
            child: Column(
              children: [
                AppTheme.goldDivider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!user.isStudent) _buildWelcomeBanner(user),
                      if (!user.isStudent) const SizedBox(height: 20),
                      _buildFeatureGrid(context, user),
                      if (user.isAdmin) ...[
                        const SizedBox(height: 24),
                        _buildAdminBanner(context),
                      ],
                      const SizedBox(height: 20),
                      _buildMottoFooter(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, UserModel user, AuthProvider auth) {
    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      floating: false,
      backgroundColor: AppTheme.navy,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: AppTheme.navyHeaderDecoration,
          child: SafeArea(
            child: Stack(
              children: [
                Positioned(
                  right: -30, top: -30,
                  child: Opacity(
                    opacity: 0.06,
                    child: Container(
                      width: 160, height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.gold, width: 2),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 10, top: 10,
                  child: Opacity(
                    opacity: 0.04,
                    child: Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.gold, width: 1.5),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildLogoMark(),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('ACHC Hub',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                                fontFamily: 'Georgia',
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text('Aquinas Columbus Homeschool',
                              style: TextStyle(
                                color: AppTheme.goldLight.withValues(alpha: 0.9),
                                fontSize: 11,
                                letterSpacing: 0.4,
                              ),
                            ),
                            if (_coopWeekLabel != null) ...[
                              const SizedBox(height: 3),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.gold.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _coopWeekLabel!,
                                  style: const TextStyle(
                                      color: AppTheme.goldLight,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ] else
                              const SizedBox(height: 6),
                            _buildRolePill(user),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const SettingsScreen())),
                            child: _buildAvatarRing(user),
                          ),
                          const SizedBox(height: 4),
                          Text(user.displayName.split(' ').first,
                            style: const TextStyle(color: Colors.white70, fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined, size: 20),
          onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SettingsScreen())),
        ),
      ],
    );
  }

  Widget _buildLogoMark() {
    return Container(
      width: 52, height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.gold, width: 1.5),
        color: AppTheme.gold.withValues(alpha: 0.1),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 8,
            child: Icon(Icons.menu_book_rounded,
              color: AppTheme.goldLight, size: 22),
          ),
          Positioned(
            top: 5,
            child: Icon(Icons.add, color: AppTheme.gold, size: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarRing(UserModel user) {
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.gold, width: 1.5),
        color: AppTheme.navyMid,
      ),
      child: Center(
        child: Text(
          user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
          style: const TextStyle(color: Colors.white, fontSize: 18,
            fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildRolePill(UserModel user) {
    final label = user.isAdmin ? 'ADMIN' : user.isStudent ? 'STUDENT' : 'PARENT';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(4),
        color: AppTheme.gold.withValues(alpha: 0.12),
      ),
      child: Text(label,
        style: const TextStyle(color: AppTheme.goldLight, fontSize: 10,
          fontWeight: FontWeight.w700, letterSpacing: 1.2)),
    );
  }

  // ── Welcome Banner ────────────────────────────────────────────
  Widget _buildWelcomeBanner(UserModel user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.goldLight, width: 1),
              color: AppTheme.navy.withValues(alpha: 0.06),
            ),
            child: const Icon(Icons.school_outlined, color: AppTheme.navy, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_greeting()} 👋',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 2),
                Text(user.displayName,
                  style: const TextStyle(color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700, fontSize: 15, fontFamily: 'Georgia')),
                if (_coopWeekLabel != null) ...[
                  const SizedBox(height: 3),
                  Text(_coopWeekLabel!,
                    style: const TextStyle(
                        color: AppTheme.navy,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),
          Container(
            width: 1, height: 32,
            color: AppTheme.goldLight.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              const Text('ESTD.', style: TextStyle(color: AppTheme.gold,
                fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 1)),
              const Text('2019', style: TextStyle(color: AppTheme.navy,
                fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Feature Grid ──────────────────────────────────────────────
  Widget _buildFeatureGrid(BuildContext context, UserModel user) {
    final features = _features(user);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AppTheme.sectionHeader('Quick Access'),
          ],
        ),
        const SizedBox(height: 8),
        // ── For students: vertical list ──
        if (user.isStudent)
          Column(
            children: features.map((f) => _buildStudentRow(context, f, user)).toList(),
          )
        else
          // ── For parents/admins: 3-column grid ──
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.88,
            // Extra padding so badge dots aren't clipped at the grid edge
            padding: const EdgeInsets.only(top: 8, right: 8),
            children: features.map((f) => _FeatureTile(
              item: f,
              badgeEnabled: _notifPrefs[f.notifKey] ?? false,
              db: _db,
              userUid: user.uid,
              lastSeenTs: _lastSeenTs['lastseen_${f.seenKey}'] ?? 0,
              onTap: () {
                _markSeen(f.seenKey);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => f.screen));
              },
              onClearBadge: () => _clearBadge(f.seenKey),
            )).toList(),
          ),
      ],
    );
  }

  Widget _buildStudentRow(BuildContext context, _FeatureItem f, UserModel user) {
    return GestureDetector(
      onTap: () {
        _markSeen(f.seenKey);
        Navigator.push(context, MaterialPageRoute(builder: (_) => f.screen));
      },
      onLongPress: () => _showClearBadgeMenu(context, f.label, f.seenKey),
      child: Stack(
        children: [
          // Tile
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: AppTheme.featureTileDecoration(f.color),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Icon with badge overlaid
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: f.color.withValues(alpha: 0.1),
                          border: Border.all(
                            color: f.color.withValues(alpha: 0.25), width: 1),
                        ),
                        child: Icon(f.icon, color: f.color, size: 22),
                      ),
                      if (_notifPrefs[f.notifKey] ?? false)
                        Positioned(
                          top: -5,
                          right: -5,
                          child: _BadgeCounter(
                            notifKey: f.notifKey ?? '',
                            badgeQuery: f.badgeQuery,
                            db: _db,
                            userUid: user.uid,
                            tileColor: f.color,
                            lastSeenTs: _lastSeenTs['lastseen_${f.seenKey}'] ?? 0,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Text(f.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: f.color,
                    )),
                  const Spacer(),
                  Icon(Icons.chevron_right,
                    color: f.color.withValues(alpha: 0.5), size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_FeatureItem> _features(UserModel user) {
    if (user.isStudent) {
      return [
        _FeatureItem('Assignments', Icons.assignment_outlined,
          AppTheme.assignmentsColor, const AssignmentsScreen(),
          notifKey: NotificationPrefsService.keyAssignments,
          seenKey: 'assignments',
          badgeQuery: (db, uid) => db.collection('assignments')
              .where('assignedUids', arrayContains: uid)
              .where('status', isEqualTo: 'pending')),
        _FeatureItem('Classes', Icons.menu_book_outlined,
          AppTheme.classesColor, const ClassesScreen(),
          seenKey: 'classes'),
        _FeatureItem('Feeds', Icons.dynamic_feed_outlined,
          AppTheme.feedsColor, const FeedsScreen(),
          notifKey: NotificationPrefsService.keyFeedAnnouncements,
          seenKey: 'feeds'),
        _FeatureItem('Training', Icons.school_outlined,
          const Color(0xFF5D4037), const _PlaceholderScreen(title: 'Training Modules'),
          seenKey: 'training'),
        _FeatureItem('Memory Work', Icons.auto_stories_outlined,
          const Color(0xFF1565C0), const _PlaceholderScreen(title: 'Memory Work'),
          seenKey: 'memorywork'),
      ];
    }
    return [
      _FeatureItem('Assignments', Icons.assignment_outlined,
        AppTheme.assignmentsColor, const AssignmentsScreen(),
        notifKey: NotificationPrefsService.keyAssignments,
        seenKey: 'assignments',
        badgeQuery: (db, uid) => db.collection('assignments')
            .where('assignedUids', arrayContains: uid)
            .where('status', isEqualTo: 'pending')),
      _FeatureItem('Classes', Icons.menu_book_outlined,
        AppTheme.classesColor, const ClassesScreen(),
        seenKey: 'classes'),
      _FeatureItem('Messages', Icons.chat_bubble_outline,
        AppTheme.messagesColor, const MessagesScreen(),
        notifKey: NotificationPrefsService.keyMessages,
        seenKey: 'messages',
        badgeQuery: (db, uid) => db.collection('chatRooms')
            .where('members', arrayContains: uid)),
      _FeatureItem('Calendar', Icons.calendar_today_outlined,
        AppTheme.calendarColor, const CalendarScreen(),
        notifKey: NotificationPrefsService.keyCalendar,
        seenKey: 'calendar'),
      _FeatureItem('Check-In', Icons.how_to_reg_outlined,
        AppTheme.checkInColor, const CheckInScreen(),
        seenKey: 'checkin'),
      _FeatureItem('Files', Icons.folder_outlined,
        AppTheme.filesColor, const FilesScreen(),
        notifKey: NotificationPrefsService.keyFiles,
        seenKey: 'files'),
      _FeatureItem('Feeds', Icons.dynamic_feed_outlined,
        AppTheme.feedsColor, const FeedsScreen(),
        notifKey: NotificationPrefsService.keyFeedAnnouncements,
        seenKey: 'feeds'),
      _FeatureItem('Training', Icons.school_outlined,
        const Color(0xFF5D4037), const _PlaceholderScreen(title: 'Training Modules'),
        seenKey: 'training'),
      _FeatureItem('Memory Work', Icons.auto_stories_outlined,
        const Color(0xFF1565C0), const _PlaceholderScreen(title: 'Memory Work'),
        seenKey: 'memorywork'),
    ];
  }

  // ── Admin Banner ──────────────────────────────────────────────
  Widget _buildAdminBanner(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(context,
        MaterialPageRoute(builder: (_) => const AdminScreen())),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.navy,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.admin_panel_settings_outlined,
                color: AppTheme.goldLight, size: 22),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Admin Dashboard',
                    style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w700, fontSize: 14)),
                  SizedBox(height: 2),
                  Text('Manage members, announcements & settings',
                    style: TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.gold, size: 20),
          ],
        ),
      ),
    );
  }

  // ── Motto Footer ──────────────────────────────────────────────
  Widget _buildMottoFooter() {
    return Center(
      child: Column(
        children: [
          AppTheme.goldDivider(indent: 60),
          const SizedBox(height: 10),
          const Text('Homeschool Community · Est. 2019',
            style: TextStyle(color: AppTheme.textHint, fontSize: 11,
              letterSpacing: 0.8)),
        ],
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _showClearBadgeMenu(BuildContext context, String label, String seenKey) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_off_outlined,
                  color: AppTheme.navy),
              title: Text('Clear badge for $label'),
              subtitle: const Text('Mark all as seen'),
              onTap: () {
                Navigator.pop(context);
                _clearBadge(seenKey);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Feature Item Model ─────────────────────────────────────────────
class _FeatureItem {
  final String label;
  final IconData icon;
  final Color color;
  final Widget screen;
  final String? notifKey;
  final String seenKey;
  final Query Function(FirebaseFirestore, String)? badgeQuery;
  _FeatureItem(this.label, this.icon, this.color, this.screen,
      {this.notifKey, required this.seenKey, this.badgeQuery});
}

// ── Feature Tile (3-col grid for parents/admins) ──────────────────
class _FeatureTile extends StatelessWidget {
  final _FeatureItem item;
  final bool badgeEnabled;
  final FirebaseFirestore db;
  final String userUid;
  final int lastSeenTs;
  final VoidCallback onTap;
  final VoidCallback onClearBadge;

  const _FeatureTile({
    required this.item,
    required this.badgeEnabled,
    required this.db,
    required this.userUid,
    required this.lastSeenTs,
    required this.onTap,
    required this.onClearBadge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (_) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)),
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_off_outlined,
                      color: AppTheme.navy),
                  title: Text('Clear badge for ${item.label}'),
                  subtitle: const Text('Mark all as seen'),
                  onTap: () {
                    Navigator.pop(context);
                    onClearBadge();
                  },
                ),
              ],
            ),
          ),
        );
      },
      child: Container(
        decoration: AppTheme.featureTileDecoration(item.color),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon with badge overlaid on top-right of the circle
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: item.color.withValues(alpha: 0.08),
                    border: Border.all(
                      color: item.color.withValues(alpha: 0.25), width: 1),
                  ),
                  child: Icon(item.icon, color: item.color, size: 24),
                ),
                if (badgeEnabled && item.notifKey != null)
                  Positioned(
                    top: -5,
                    right: -5,
                    child: _BadgeCounter(
                      notifKey: item.notifKey!,
                      badgeQuery: item.badgeQuery,
                      db: db,
                      userUid: userUid,
                      tileColor: item.color,
                      lastSeenTs: lastSeenTs,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(item.label,
              style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: item.color, letterSpacing: 0.2),
              textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── Badge Counter ─────────────────────────────────────────────────
class _BadgeCounter extends StatelessWidget {
  final String notifKey;
  final Query Function(FirebaseFirestore, String)? badgeQuery;
  final FirebaseFirestore db;
  final String userUid;
  final Color tileColor;
  final int lastSeenTs;

  const _BadgeCounter({
    required this.notifKey,
    this.badgeQuery,
    required this.db,
    required this.userUid,
    required this.tileColor,
    required this.lastSeenTs,
  });

  @override
  Widget build(BuildContext context) {
    if (badgeQuery == null) {
      // For sections without a live query, only show dot if never visited
      if (lastSeenTs > 0) return const SizedBox.shrink();
      return Container(
        width: 12, height: 12,
        decoration: BoxDecoration(
          color: AppTheme.error,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: badgeQuery!(db, userUid).snapshots(),
      builder: (_, snap) {
        int count = 0;
        if (notifKey == NotificationPrefsService.keyMessages) {
          count = (snap.data?.docs ?? []).where((d) {
            final data = d.data() as Map;
            // Count rooms with unread messages newer than last-seen timestamp
            final unread = data['unread_$userUid'] as int? ?? 0;
            return unread > 0;
          }).length;
        } else {
          // Count items newer than lastSeenTs
          count = (snap.data?.docs ?? []).where((d) {
            final data = d.data() as Map;
            final ts = data['createdAt'] ?? data['timestamp'];
            if (ts == null) return false;
            final ms = ts is Timestamp
                ? ts.millisecondsSinceEpoch
                : ts as int;
            return ms > lastSeenTs;
          }).length;
          // If no createdAt field, fallback to total count
          if (count == 0 && lastSeenTs == 0) {
            count = snap.data?.docs.length ?? 0;
          }
        }
        if (count == 0) return const SizedBox.shrink();
        return Container(
          constraints: const BoxConstraints(minWidth: 18),
          height: 18,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: AppTheme.error,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: Center(
            child: Text(
              count > 99 ? '99+' : '$count',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800),
            ),
          ),
        );
      },
    );
  }
}

// ── Notification Settings Sheet ────────────────────────────────────
class _NotifSettingsSheet extends StatefulWidget {
  final Map<String, bool> prefs;
  final Future<void> Function(String key, bool value) onChanged;
  const _NotifSettingsSheet({required this.prefs, required this.onChanged});

  @override
  State<_NotifSettingsSheet> createState() => _NotifSettingsSheetState();
}

class _NotifSettingsSheetState extends State<_NotifSettingsSheet> {
  late Map<String, bool> _prefs;

  @override
  void initState() {
    super.initState();
    _prefs = Map.from(widget.prefs);
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      _NotifItem('Assignments', Icons.assignment_outlined,
          AppTheme.assignmentsColor, NotificationPrefsService.keyAssignments),
      _NotifItem('Messages', Icons.chat_bubble_outline,
          AppTheme.messagesColor, NotificationPrefsService.keyMessages),
      _NotifItem('Calendar Events', Icons.calendar_today_outlined,
          AppTheme.calendarColor, NotificationPrefsService.keyCalendar),
      _NotifItem('Files', Icons.folder_outlined,
          AppTheme.filesColor, NotificationPrefsService.keyFiles),
      _NotifItem('Announcements (always on)', Icons.campaign_outlined,
          AppTheme.feedsColor, NotificationPrefsService.keyFeedAnnouncements,
          locked: true),
      _NotifItem('Social Feed', Icons.people_outline,
          AppTheme.photosColor, NotificationPrefsService.keyFeedSocial),
      _NotifItem('Prayer Feed', Icons.volunteer_activism_outlined,
          AppTheme.prayerColor, NotificationPrefsService.keyFeedPrayer),
    ];

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.notifications_outlined, size: 22,
                      color: AppTheme.navy),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Notification Badge Settings',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Georgia')),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Choose which sections show a badge counter on the home screen. Long-press any tile to clear its badge.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(),
            Expanded(
              child: ListView.builder(
                controller: ctrl,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final item = items[i];
                  final isOn = _prefs[item.key] ?? false;
                  return ListTile(
                    leading: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: item.color.withValues(alpha: 0.1),
                      ),
                      child: Icon(item.icon, color: item.color, size: 18),
                    ),
                    title: Text(item.label,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    trailing: Switch(
                      value: isOn,
                      onChanged: item.locked
                          ? null
                          : (v) async {
                              setState(() => _prefs[item.key] = v);
                              await widget.onChanged(item.key, v);
                            },
                      activeTrackColor: item.color,
                      activeThumbColor: item.color,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotifItem {
  final String label;
  final IconData icon;
  final Color color;
  final String key;
  final bool locked;
  const _NotifItem(this.label, this.icon, this.color, this.key,
      {this.locked = false});
}

// ── Placeholder Screen for upcoming features ──────────────────────────────────
class _PlaceholderScreen extends StatelessWidget {
  final String title;
  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.navy.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(64),
              ),
              child: const Icon(Icons.construction_outlined,
                  size: 64, color: AppTheme.navy),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.navy),
            ),
            const SizedBox(height: 12),
            const Text(
              'Coming Soon!',
              style: TextStyle(
                  fontSize: 15,
                  color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'This feature is under development and will be available in a future update.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: AppTheme.textTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
