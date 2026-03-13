// lib/screens/admin/admin_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../utils/app_theme.dart';
import 'manage_members_screen.dart';
import 'attendance_history_screen.dart';
import 'coop_calendar_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _db = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: const Color(0xFF7B1FA2),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLiveStatCards(),
            const SizedBox(height: 20),
            _buildActionCards(context),
            const SizedBox(height: 20),
            _buildMembersSection(context),
          ],
        ),
      ),
    );
  }

  // ── Live Stats ─────────────────────────────────────────────────
  Widget _buildLiveStatCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Co-op Overview',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 12),
        // Students + Families row
        StreamBuilder<QuerySnapshot>(
          stream: _db.collection('users').snapshots(),
          builder: (ctx, snap) {
            final docs = snap.data?.docs ?? [];
            final studentCount = docs
                .where((d) {
                  final r = (d.data() as Map)['role'] as String? ?? '';
                  return r == 'student' || r == 'kid';
                })
                .length;
            final familySet = <String>{};
            for (final d in docs) {
              final fid = (d.data() as Map)['familyId'] as String?;
              if (fid != null && fid.isNotEmpty) familySet.add(fid);
            }
            return Row(
              children: [
                Expanded(
                    child: _buildStatCard('Students',
                        Icons.school_outlined, '$studentCount',
                        const Color(0xFF7B1FA2))),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildStatCard('Families',
                        Icons.family_restroom, '${familySet.length}',
                        AppTheme.navy)),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        // Assignments completed + check-ins today row
        Row(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _db
                    .collection('assignments')
                    .where('status', isEqualTo: 'submitted')
                    .where('updatedAt',
                        isGreaterThan: Timestamp.fromDate(
                            DateTime.now().subtract(const Duration(days: 7))))
                    .snapshots(),
                builder: (ctx, snap) {
                  final count = snap.data?.docs.length ?? 0;
                  return _buildStatCard(
                      'Completed This Week',
                      Icons.assignment_turned_in_outlined,
                      '$count',
                      AppTheme.assignmentsColor);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _db
                    .collection('checkins')
                    .where('date',
                        isEqualTo:
                            DateFormat('yyyy-MM-dd').format(DateTime.now()))
                    .snapshots(),
                builder: (ctx, snap) {
                  final count = snap.data?.docs.length ?? 0;
                  return _buildStatCard(
                      'Check-Ins Today',
                      Icons.check_circle_outline,
                      '$count',
                      AppTheme.checkInColor);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String label, IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: color),
                ),
                Text(
                  label,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Quick Actions ──────────────────────────────────────────────
  Widget _buildActionCards(BuildContext context) {
    final actions = [
      {
        'icon': Icons.announcement_outlined,
        'label': 'Broadcast\nAnnouncement',
        'color': AppTheme.feedsColor,
        'action': () => _broadcastAnnouncement(context),
      },
      {
        'icon': Icons.manage_accounts_outlined,
        'label': 'Manage\nMembers',
        'color': AppTheme.navy,
        'action': () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ManageMembersScreen())),
      },
      {
        'icon': Icons.history_outlined,
        'label': 'Attendance\nHistory',
        'color': AppTheme.checkInColor,
        'action': () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AttendanceHistoryScreen())),
      },
      {
        'icon': Icons.settings_outlined,
        'label': 'Co-op\nSettings',
        'color': const Color(0xFF7B1FA2),
        'action': () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const CoopCalendarScreen())),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.4,
          children: actions.map((a) {
            final color = a['color'] as Color;
            return InkWell(
              onTap: a['action'] as VoidCallback,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(a['icon'] as IconData, color: color, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        a['label'] as String,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Members Section ────────────────────────────────────────────
  Widget _buildMembersSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'All Members',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const ManageMembersScreen())),
              icon: const Icon(Icons.manage_accounts_outlined, size: 16),
              label: const Text('Manage'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: _db.collection('users').snapshots(),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snap.data?.docs ?? [];

            if (docs.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No members yet',
                      style: TextStyle(color: AppTheme.textSecondary)),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              itemBuilder: (ctx, i) {
                final data = docs[i].data() as Map<String, dynamic>;
                final name =
                    data['displayName'] as String? ?? 'Unknown';
                final email = data['email'] as String? ?? '';
                final role = data['role'] as String? ?? 'parent';
                final isStudent = role == 'student' || role == 'kid';
                final roleColor = role == 'admin'
                    ? const Color(0xFF7B1FA2)
                    : isStudent
                        ? AppTheme.gold
                        : AppTheme.navy;
                final roleLabel = role == 'admin'
                    ? 'ADMIN'
                    : isStudent
                        ? 'STUDENT'
                        : 'PARENT';

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          roleColor.withValues(alpha: 0.15),
                      child: Text(
                        name.isNotEmpty
                            ? name[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                            color: roleColor,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    title: Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600)),
                    subtitle: Text(email,
                        style: const TextStyle(fontSize: 12)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        roleLabel,
                        style: TextStyle(
                            color: roleColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ManageMembersScreen(
                          highlightUid: docs[i].id,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  // ── Broadcast Announcement ─────────────────────────────────────
  void _broadcastAnnouncement(BuildContext context) {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setS) => AlertDialog(
          title: const Text('Broadcast Announcement'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                    labelText: 'Title', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: contentCtrl,
                decoration: const InputDecoration(
                    labelText: 'Message',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder()),
                maxLines: 4,
                minLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (contentCtrl.text.trim().isEmpty) return;
                      setS(() => saving = true);
                      await _db.collection('feeds').add({
                        'type': 'announcement',
                        'title': titleCtrl.text.trim(),
                        'content': contentCtrl.text.trim(),
                        'authorId': 'admin',
                        'authorName': 'Admin',
                        'likedBy': [],
                        'commentCount': 0,
                        'pollOptions': [],
                        'pollVotes': {},
                        'inKidFeed': false,
                        'inStudentFeed': false,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Post'),
            ),
          ],
        ),
      ),
    );
  }
}
