// lib/screens/home/home_screen.dart  — with notification badges + co-op week label
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/notification_prefs_service.dart';
import '../assignments/assignments_screen.dart';
import '../messages/messages_screen.dart';
import '../calendar/calendar_screen.dart';
import '../photos/photos_screen.dart';
import '../checkin/checkin_screen.dart';
import '../files/files_screen.dart';
import '../feeds/feeds_screen.dart';
import '../settings/settings_screen.dart';
import '../admin/admin_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = FirebaseFirestore.instance;
  Map<String, bool> _notifPrefs = {};
  String? _coopWeekLabel;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadCoopWeekLabel();
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
        setState(() =>
            _coopWeekLabel = doc.data()?['label'] as String?);
      }
    } catch (_) {}
  }

  String _currentWeekKey() {
    final now = DateTime.now();
    // Monday-based week key
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
                            // Co-op week label
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
            const Spacer(),
            // Notification settings button
            if (!user.isStudent)
              TextButton.icon(
                onPressed: () => _showNotifSettings(context),
                icon: const Icon(Icons.notifications_outlined, size: 16),
                label: const Text('Badges', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8)),
              ),
          ],
        ),
        GridView.count(
          crossAxisCount: user.isStudent ? 1 : 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: user.isStudent ? 3.5 : 0.88,
          children: features.map((f) => _FeatureTile(
            item: f,
            badgeEnabled: _notifPrefs[f.notifKey] ?? false,
            db: _db,
            userUid: user.uid,
          )).toList(),
        ),
      ],
    );
  }

  List<_FeatureItem> _features(UserModel user) {
    if (user.isStudent) {
      return [
        _FeatureItem('Assignments', Icons.assignment_outlined,
          AppTheme.assignmentsColor, const AssignmentsScreen(),
          notifKey: NotificationPrefsService.keyAssignments,
          badgeQuery: (db, uid) => db.collection('assignments')
              .where('assignedUids', arrayContains: uid)
              .where('status', isEqualTo: 'pending')),
        _FeatureItem('Prayer', Icons.volunteer_activism_outlined,
          AppTheme.prayerColor, const FeedsScreen(initialTab: 2),
          notifKey: NotificationPrefsService.keyFeedPrayer),
      ];
    }
    return [
      _FeatureItem('Assignments', Icons.assignment_outlined,
        AppTheme.assignmentsColor, const AssignmentsScreen(),
        notifKey: NotificationPrefsService.keyAssignments),
      _FeatureItem('Messages', Icons.chat_bubble_outline,
        AppTheme.messagesColor, const MessagesScreen(),
        notifKey: NotificationPrefsService.keyMessages,
        badgeQuery: (db, uid) => db.collection('chatRooms')
            .where('members', arrayContains: uid)),
      _FeatureItem('Calendar', Icons.calendar_today_outlined,
        AppTheme.calendarColor, const CalendarScreen(),
        notifKey: NotificationPrefsService.keyCalendar),
      _FeatureItem('Photos', Icons.photo_library_outlined,
        AppTheme.photosColor, const PhotosScreen(),
        notifKey: NotificationPrefsService.keyPhotos),
      _FeatureItem('Check-In', Icons.how_to_reg_outlined,
        AppTheme.checkInColor, const CheckInScreen()),
      _FeatureItem('Files', Icons.folder_outlined,
        AppTheme.filesColor, const FilesScreen(),
        notifKey: NotificationPrefsService.keyFiles),
      _FeatureItem('Feeds', Icons.dynamic_feed_outlined,
        AppTheme.feedsColor, const FeedsScreen(),
        notifKey: NotificationPrefsService.keyFeedAnnouncements),
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

  // ── Notification Settings Sheet ────────────────────────────────
  void _showNotifSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NotifSettingsSheet(
        prefs: Map.from(_notifPrefs),
        onChanged: (key, value) async {
          await NotificationPrefsService.setPref(key, value);
          await _loadPrefs();
        },
      ),
    );
  }
}

// ── Feature Tile with Badge ───────────────────────────────────────
class _FeatureItem {
  final String label;
  final IconData icon;
  final Color color;
  final Widget screen;
  final String? notifKey;
  final Query Function(FirebaseFirestore, String)? badgeQuery;
  _FeatureItem(this.label, this.icon, this.color, this.screen,
      {this.notifKey, this.badgeQuery});
}

class _FeatureTile extends StatelessWidget {
  final _FeatureItem item;
  final bool badgeEnabled;
  final FirebaseFirestore db;
  final String userUid;
  const _FeatureTile({
    required this.item,
    required this.badgeEnabled,
    required this.db,
    required this.userUid,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
        MaterialPageRoute(builder: (_) => item.screen)),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: AppTheme.featureTileDecoration(item.color),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
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
                const SizedBox(height: 8),
                Text(item.label,
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: item.color, letterSpacing: 0.2),
                  textAlign: TextAlign.center),
              ],
            ),
          ),
          // Badge counter
          if (badgeEnabled && item.notifKey != null)
            Positioned(
              top: 4,
              right: 4,
              child: _BadgeCounter(
                notifKey: item.notifKey!,
                badgeQuery: item.badgeQuery,
                db: db,
                userUid: userUid,
                tileColor: item.color,
              ),
            ),
        ],
      ),
    );
  }
}

class _BadgeCounter extends StatelessWidget {
  final String notifKey;
  final Query Function(FirebaseFirestore, String)? badgeQuery;
  final FirebaseFirestore db;
  final String userUid;
  final Color tileColor;
  const _BadgeCounter({
    required this.notifKey,
    this.badgeQuery,
    required this.db,
    required this.userUid,
    required this.tileColor,
  });

  @override
  Widget build(BuildContext context) {
    if (badgeQuery == null) {
      // Generic dot badge for sections without specific query
      return Container(
        width: 10, height: 10,
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
          // For messages: count rooms with unread
          count = (snap.data?.docs ?? []).where((d) {
            final unread = (d.data() as Map)['unread_$userUid'] as int? ?? 0;
            return unread > 0;
          }).length;
        } else {
          count = snap.data?.docs.length ?? 0;
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
      _NotifItem('Photos', Icons.photo_library_outlined,
          AppTheme.photosColor, NotificationPrefsService.keyPhotos),
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
                'Choose which sections show a badge counter on the home screen.',
                style: TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary),
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
                      activeColor: item.color,
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
