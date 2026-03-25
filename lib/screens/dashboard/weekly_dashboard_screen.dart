// lib/screens/dashboard/weekly_dashboard_screen.dart
// P2-1: Weekly Dashboard — aggregates a family's week at a glance.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/memory_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_animations.dart';
import '../../utils/week_utils.dart';
import '../coverage/coverage_screen.dart';
import '../memory/memory_home_screen.dart';

class WeeklyDashboardScreen extends StatefulWidget {
  final UserModel user;
  const WeeklyDashboardScreen({super.key, required this.user});

  @override
  State<WeeklyDashboardScreen> createState() => _WeeklyDashboardScreenState();
}

class _WeeklyDashboardScreenState extends State<WeeklyDashboardScreen> {
  DateTime _selectedWeek = DateTime.now();

  DateTime get _weekStart => WeekUtils.weekStart(_selectedWeek);
  DateTime get _weekEnd => WeekUtils.weekEnd(_selectedWeek);
  String get _weekLabel => WeekUtils.weekLabel(_selectedWeek);

  void _goToPrevWeek() =>
      setState(() => _selectedWeek = WeekUtils.prevWeek(_selectedWeek));
  void _goToNextWeek() =>
      setState(() => _selectedWeek = WeekUtils.nextWeek(_selectedWeek));

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.navyDark,
        foregroundColor: Colors.white,
        title: const Text('My Week',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
      ),
      body: Column(
        children: [
          _WeekSelector(
            label: _weekLabel,
            isCurrentWeek: WeekUtils.isCurrentWeek(_selectedWeek),
            onPrev: _goToPrevWeek,
            onNext: _goToNextWeek,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _ClassesCard(user: user, weekStart: _weekStart, weekEnd: _weekEnd)
                    .animate(delay: 0.ms)
                    .fadeIn(duration: AppAnimations.cardFadeInDuration)
                    .moveY(begin: 16, end: 0),
                const SizedBox(height: 12),
                _AssignmentsCard(user: user, weekStart: _weekStart, weekEnd: _weekEnd)
                    .animate(delay: 100.ms)
                    .fadeIn(duration: AppAnimations.cardFadeInDuration)
                    .moveY(begin: 16, end: 0),
                const SizedBox(height: 12),
                _VolunteerCard(user: user, weekStart: _weekStart)
                    .animate(delay: 200.ms)
                    .fadeIn(duration: AppAnimations.cardFadeInDuration)
                    .moveY(begin: 16, end: 0),
                const SizedBox(height: 12),
                _MemoryWorkCard(user: user)
                    .animate(delay: 300.ms)
                    .fadeIn(duration: AppAnimations.cardFadeInDuration)
                    .moveY(begin: 16, end: 0),
                if (user.canMentor || user.isAdmin) ...[
                  const SizedBox(height: 12),
                  _CoverageNoticesCard(user: user)
                      .animate(delay: 400.ms)
                      .fadeIn(duration: AppAnimations.cardFadeInDuration)
                      .moveY(begin: 16, end: 0),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Week Selector ─────────────────────────────────────────────────────────────
class _WeekSelector extends StatelessWidget {
  final String label;
  final bool isCurrentWeek;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _WeekSelector({
    required this.label,
    required this.isCurrentWeek,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.navyDark,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white70),
            onPressed: onPrev,
          ),
          AnimatedSwitcher(
            duration: AppAnimations.weekChangeDuration,
            child: Column(
              key: ValueKey(label),
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                if (isCurrentWeek)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppTheme.gold.withValues(alpha: 0.5)),
                    ),
                    child: const Text('This Week',
                        style:
                            TextStyle(color: AppTheme.gold, fontSize: 11)),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white70),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

// ── Base Section Card ─────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;
  final bool initiallyExpanded;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
    this.initiallyExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppTheme.navyDark)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [child],
      ),
    );
  }
}

// ── Classes Card ──────────────────────────────────────────────────────────────
class _ClassesCard extends StatelessWidget {
  final UserModel user;
  final DateTime weekStart;
  final DateTime weekEnd;
  const _ClassesCard(
      {required this.user,
      required this.weekStart,
      required this.weekEnd});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'My Classes This Week',
      icon: Icons.menu_book_outlined,
      color: AppTheme.classesColor,
      child: StreamBuilder<QuerySnapshot>(
        stream: user.mentorClassIds.isEmpty
            ? FirebaseFirestore.instance
                .collection('classes')
                .where('enrolledStudents', arrayContains: user.uid)
                .snapshots()
            : FirebaseFirestore.instance
                .collection('classes')
                .where('mentorUid', isEqualTo: user.uid)
                .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const _LoadingRow();
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return _EmptyRow('No classes found for this week.');
          }
          return Column(
            children: docs.map((doc) {
              final d = doc.data() as Map<String, dynamic>;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.class_,
                    color: AppTheme.classesColor, size: 20),
                title: Text(d['name'] as String? ?? 'Class',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                    '${d['schedule'] ?? ''} · ${d['room'] ?? ''}',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textHint)),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

// ── Assignments Card ──────────────────────────────────────────────────────────
class _AssignmentsCard extends StatelessWidget {
  final UserModel user;
  final DateTime weekStart;
  final DateTime weekEnd;
  const _AssignmentsCard(
      {required this.user,
      required this.weekStart,
      required this.weekEnd});

  Color _chipColor(DateTime due) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(due.year, due.month, due.day);
    if (dueDay.isBefore(today)) return Colors.red;
    if (dueDay.isAtSameMomentAs(today)) return Colors.amber;
    return Colors.green;
  }

  String _chipLabel(DateTime due) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(due.year, due.month, due.day);
    if (dueDay.isBefore(today)) return 'Overdue';
    if (dueDay.isAtSameMomentAs(today)) return 'Due Today';
    return 'Upcoming';
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Assignments Due',
      icon: Icons.assignment_outlined,
      color: AppTheme.assignmentsColor,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('assignments')
            .where('studentId', isEqualTo: user.uid)
            .where('dueDate',
                isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
            .where('dueDate',
                isLessThanOrEqualTo: Timestamp.fromDate(weekEnd))
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const _LoadingRow();
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return _EmptyRow('No assignments due this week 🎉');
          }
          return Column(
            children: docs.map((doc) {
              final d = doc.data() as Map<String, dynamic>;
              final due =
                  (d['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now();
              final color = _chipColor(due);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(d['title'] as String? ?? 'Assignment',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle:
                    Text(d['className'] as String? ?? '',
                        style: const TextStyle(fontSize: 12)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: color.withValues(alpha: 0.5)),
                  ),
                  child: Text(_chipLabel(due),
                      style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

// ── Volunteer Duties Card ─────────────────────────────────────────────────────
class _VolunteerCard extends StatelessWidget {
  final UserModel user;
  final DateTime weekStart;
  const _VolunteerCard({required this.user, required this.weekStart});

  @override
  Widget build(BuildContext context) {
    final weekId = WeekUtils.weekId(weekStart);
    return _SectionCard(
      title: 'My Volunteer Duties',
      icon: Icons.volunteer_activism_outlined,
      color: AppTheme.gold,
      child: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('volunteer_rotations')
            .doc(weekId)
            .get(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const _LoadingRow();
          }
          if (!snap.hasData || !snap.data!.exists) {
            return _EmptyRow('No duties this week 🎉');
          }
          final data = snap.data!.data() as Map<String, dynamic>;
          final slots = (data['slots'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>();
          final myName = user.displayName.toLowerCase();
          final mySlots = slots.where((s) {
            final names = (s['names'] as List<dynamic>? ?? [])
                .cast<String>();
            return names.any(
                (n) => n.toLowerCase().contains(myName));
          }).toList();

          if (mySlots.isEmpty) {
            return _EmptyRow('No duties this week 🎉');
          }
          return Column(
            children: mySlots.map((s) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_available,
                  color: AppTheme.gold, size: 20),
              title: Text(s['role'] as String? ?? 'Duty',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(s['day'] as String? ?? '',
                  style: const TextStyle(fontSize: 12)),
            )).toList(),
          );
        },
      ),
    );
  }
}

// ── Memory Work Card ──────────────────────────────────────────────────────────
class _MemoryWorkCard extends StatelessWidget {
  final UserModel user;
  const _MemoryWorkCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final memProv = context.watch<MemoryProvider>();
    final unit = memProv.currentUnit;
    final cycle = memProv.activeCycle?.name ?? 'Cycle 2';
    final subjects = memProv.subjects;
    final total = subjects.length;
    // Count subjects that have been practiced (progress recorded)
    final done = subjects.where((s) {
      final p = memProv.progressFor(s.id);
      return p != null && p.lastPracticed != null;
    }).length;
    final fraction = total == 0 ? 0.0 : done / total;

    return _SectionCard(
      title: 'Memory Work This Week',
      icon: Icons.auto_stories_outlined,
      color: AppTheme.memoryWorkColor,
      child: Column(
        children: [
          Row(
            children: [
              _ProgressRing(fraction: fraction, done: done, total: total),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$cycle · Unit $unit',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.navyDark,
                            fontSize: 15)),
                    const SizedBox(height: 4),
                    Text('$done of $total subjects practiced',
                        style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('Practice Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.memoryWorkColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          MemoryWorkHomeScreen(user: user))),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Progress Ring ─────────────────────────────────────────────────────────────
class _ProgressRing extends StatelessWidget {
  final double fraction;
  final int done;
  final int total;
  const _ProgressRing(
      {required this.fraction, required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: fraction),
        duration: const Duration(milliseconds: 600),
        builder: (_, value, __) {
          return Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: value,
                strokeWidth: 6,
                backgroundColor: AppTheme.memoryWorkColor.withValues(alpha: 0.15),
                color: AppTheme.memoryWorkColor,
              ),
              Text('$done/$total',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.navyDark)),
            ],
          );
        },
      ),
    );
  }
}

// ── Coverage Notices Card ─────────────────────────────────────────────────────
class _CoverageNoticesCard extends StatelessWidget {
  final UserModel user;
  const _CoverageNoticesCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Coverage Notices',
      icon: Icons.warning_amber_rounded,
      color: Colors.orange,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('mentor_absences')
            .where('status',
                whereIn: ['pending', 'uncovered'])
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const _LoadingRow();
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return _EmptyRow('All classes are covered ✓');
          }
          return Column(
            children: [
              ...docs.take(3).map((doc) {
                final d = doc.data() as Map<String, dynamic>;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.warning_amber_rounded,
                      color: Colors.orange, size: 20),
                  title: Text(d['class_name'] as String? ?? 'Class',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      '${d['mentor_name'] ?? ''} · ${d['period'] ?? ''}',
                      style: const TextStyle(fontSize: 12)),
                );
              }),
              TextButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const CoverageScreen())),
                child: const Text('View Coverage Board →'),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
class _LoadingRow extends StatelessWidget {
  const _LoadingRow();
  @override
  Widget build(BuildContext context) => const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
}

Widget _EmptyRow(String msg) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(msg,
        style: const TextStyle(
            color: AppTheme.textHint, fontSize: 13)));
