// lib/screens/home/home_screen.dart  — Style 3: Minimalist Navy & Gold
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../../models/user_model.dart';
import '../assignments/assignments_screen.dart';
import '../messages/messages_screen.dart';
import '../calendar/calendar_screen.dart';
import '../photos/photos_screen.dart';
import '../checkin/checkin_screen.dart';
import '../files/files_screen.dart';
import '../feeds/feeds_screen.dart';
import '../settings/settings_screen.dart';
import '../admin/admin_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth  = context.watch<AuthProvider>();
    final user  = auth.currentUser;
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
                // Faint circular watermark
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
                // Content
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // ACHC Logo badge
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
                            const SizedBox(height: 6),
                            _buildRolePill(user),
                          ],
                        ),
                      ),
                      // Avatar + settings
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
        AppTheme.sectionHeader('Quick Access'),
        GridView.count(
          crossAxisCount: user.isStudent ? 1 : 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: user.isStudent ? 3.5 : 0.88,
          children: features.map((f) => _FeatureTile(item: f)).toList(),
        ),
      ],
    );
  }

  List<_FeatureItem> _features(UserModel user) {
    if (user.isStudent) {
      return [
        _FeatureItem('Assignments', Icons.assignment_outlined,
          AppTheme.assignmentsColor, const AssignmentsScreen()),
        _FeatureItem('Prayer', Icons.volunteer_activism_outlined,
          AppTheme.prayerColor, const FeedsScreen(initialTab: 2)),
      ];
    }
    return [
      _FeatureItem('Assignments', Icons.assignment_outlined,
        AppTheme.assignmentsColor, const AssignmentsScreen()),
      _FeatureItem('Messages',    Icons.chat_bubble_outline,
        AppTheme.messagesColor,   const MessagesScreen()),
      _FeatureItem('Calendar',    Icons.calendar_today_outlined,
        AppTheme.calendarColor,   const CalendarScreen()),
      _FeatureItem('Photos',      Icons.photo_library_outlined,
        AppTheme.photosColor,     const PhotosScreen()),
      _FeatureItem('Check-In',    Icons.how_to_reg_outlined,
        AppTheme.checkInColor,    const CheckInScreen()),
      _FeatureItem('Files',       Icons.folder_outlined,
        AppTheme.filesColor,      const FilesScreen()),
      _FeatureItem('Feeds',       Icons.dynamic_feed_outlined,
        AppTheme.feedsColor,      const FeedsScreen()),
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
}

// ── Feature Tile Widget ───────────────────────────────────────
class _FeatureItem {
  final String label;
  final IconData icon;
  final Color color;
  final Widget screen;
  _FeatureItem(this.label, this.icon, this.color, this.screen);
}

class _FeatureTile extends StatelessWidget {
  final _FeatureItem item;
  const _FeatureTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
        MaterialPageRoute(builder: (_) => item.screen)),
      child: Container(
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
    );
  }
}
