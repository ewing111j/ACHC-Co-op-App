// lib/screens/admin/attendance_history_screen.dart
// Per-class attendance breakdown, mentor/second status, history by week
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../utils/app_theme.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _db = FirebaseFirestore.instance;
  // Week offset: 0 = current week, -1 = last week, etc.
  int _weekOffset = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Monday of the week with [offset] weeks from now
  DateTime _weekStart(int offset) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return DateTime(monday.year, monday.month, monday.day)
        .add(Duration(days: offset * 7));
  }

  @override
  Widget build(BuildContext context) {
    final ws = _weekStart(_weekOffset);
    final we = ws.add(const Duration(days: 6));
    final weekLabel =
        '${DateFormat('MMM d').format(ws)} – ${DateFormat('MMM d, y').format(we)}';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Attendance History'),
        backgroundColor: AppTheme.navy,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'By Class'),
            Tab(text: 'All Check-Ins'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Week navigation
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() => _weekOffset--),
                ),
                Expanded(
                  child: Text(
                    'Week of $weekLabel',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _weekOffset < 0
                      ? () => setState(() => _weekOffset++)
                      : null,
                ),
              ],
            ),
          ),
          AppTheme.goldDivider(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ByClassTab(
                    db: _db, weekStart: ws, weekEnd: we),
                _AllCheckInsTab(
                    db: _db, weekStart: ws, weekEnd: we),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── By Class Tab ──────────────────────────────────────────────────
class _ByClassTab extends StatelessWidget {
  final FirebaseFirestore db;
  final DateTime weekStart;
  final DateTime weekEnd;
  const _ByClassTab(
      {required this.db, required this.weekStart, required this.weekEnd});

  List<String> get _dateRange {
    final dates = <String>[];
    for (var i = 0; i <= 6; i++) {
      dates.add(
          DateFormat('yyyy-MM-dd').format(weekStart.add(Duration(days: i))));
    }
    return dates;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db.collection('groups')
          .where('type', isEqualTo: 'class')
          .snapshots(),
      builder: (ctx, groupSnap) {
        if (groupSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final groups = groupSnap.data?.docs ?? [];
        if (groups.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.class_outlined, size: 48, color: AppTheme.textHint),
                SizedBox(height: 12),
                Text('No classes found',
                    style: TextStyle(color: AppTheme.textSecondary)),
                SizedBox(height: 8),
                Text('Create classes in Manage Members',
                    style: TextStyle(
                        color: AppTheme.textHint, fontSize: 12)),
              ],
            ),
          );
        }
        return StreamBuilder<QuerySnapshot>(
          stream: db
              .collection('checkins')
              .where('date', whereIn: _dateRange.take(10).toList())
              .snapshots(),
          builder: (ctx2, ciSnap) {
            final checkIns = ciSnap.data?.docs ?? [];

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: groups.length,
              itemBuilder: (_, i) {
                final gData = groups[i].data() as Map<String, dynamic>;
                final gName = gData['name'] as String? ?? 'Class';
                final members = List<String>.from(
                    gData['memberUids'] as List? ?? []);
                final mentors = List<String>.from(
                    gData['mentorUids'] as List? ?? []);
                final seconds = List<String>.from(
                    gData['secondUids'] as List? ?? []);

                // Who checked in from this class
                final checkedInUids = checkIns
                    .where((d) => members.contains(
                        (d.data() as Map)['uid'] as String? ?? ''))
                    .map((d) => (d.data() as Map)['uid'] as String)
                    .toSet();

                final absentUids = members
                    .where((uid) => !checkedInUids.contains(uid))
                    .toList();
                final mentorCheckedIn =
                    mentors.any((m) => checkedInUids.contains(m));
                final secondCheckedIn =
                    seconds.any((s) => checkedInUids.contains(s));

                return _ClassAttendanceCard(
                  className: gName,
                  totalStudents: members.length,
                  checkedInCount: checkedInUids.length,
                  absentUids: absentUids,
                  mentorCheckedIn: mentorCheckedIn,
                  secondCheckedIn: secondCheckedIn,
                  hasMentor: mentors.isNotEmpty,
                  hasSecond: seconds.isNotEmpty,
                  db: db,
                );
              },
            );
          },
        );
      },
    );
  }
}

// ── Class Attendance Card ─────────────────────────────────────────
class _ClassAttendanceCard extends StatefulWidget {
  final String className;
  final int totalStudents;
  final int checkedInCount;
  final List<String> absentUids;
  final bool mentorCheckedIn;
  final bool secondCheckedIn;
  final bool hasMentor;
  final bool hasSecond;
  final FirebaseFirestore db;

  const _ClassAttendanceCard({
    required this.className,
    required this.totalStudents,
    required this.checkedInCount,
    required this.absentUids,
    required this.mentorCheckedIn,
    required this.secondCheckedIn,
    required this.hasMentor,
    required this.hasSecond,
    required this.db,
  });

  @override
  State<_ClassAttendanceCard> createState() =>
      _ClassAttendanceCardState();
}

class _ClassAttendanceCardState extends State<_ClassAttendanceCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final pct = widget.totalStudents > 0
        ? widget.checkedInCount / widget.totalStudents
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.className,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15),
                        ),
                      ),
                      Icon(
                        _expanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: AppTheme.textHint,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor: AppTheme.surfaceVariant,
                      color: pct == 1.0
                          ? AppTheme.success
                          : AppTheme.warning,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '${widget.checkedInCount}/${widget.totalStudents} checked in',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary),
                      ),
                      const Spacer(),
                      // Mentor status
                      if (widget.hasMentor)
                        _StatusBadge(
                          label: 'Mentor',
                          present: widget.mentorCheckedIn,
                        ),
                      if (widget.hasMentor && widget.hasSecond)
                        const SizedBox(width: 6),
                      // Second status
                      if (widget.hasSecond)
                        _StatusBadge(
                          label: '2nd',
                          present: widget.secondCheckedIn,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Absent students list
          if (_expanded && widget.absentUids.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Absent (${widget.absentUids.length}):',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.error),
                  ),
                  const SizedBox(height: 6),
                  ...widget.absentUids.map(
                    (uid) => FutureBuilder<DocumentSnapshot>(
                      future: widget.db.collection('users').doc(uid).get(),
                      builder: (_, snap) {
                        final name = snap.data?.exists == true
                            ? (snap.data!.data()
                                    as Map)['displayName'] as String? ??
                                uid
                            : uid;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.close,
                                  size: 14,
                                  color: AppTheme.error),
                              const SizedBox(width: 6),
                              Text(name,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textSecondary)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_expanded && widget.absentUids.isEmpty) ...[
            const Divider(height: 1),
            const Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 16, color: AppTheme.success),
                  SizedBox(width: 6),
                  Text('Everyone checked in!',
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.success)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final bool present;
  const _StatusBadge({required this.label, required this.present});

  @override
  Widget build(BuildContext context) {
    final color = present ? AppTheme.success : AppTheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(present ? Icons.check : Icons.close,
              size: 11, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }
}

// ── All Check-Ins Tab ─────────────────────────────────────────────
class _AllCheckInsTab extends StatelessWidget {
  final FirebaseFirestore db;
  final DateTime weekStart;
  final DateTime weekEnd;
  const _AllCheckInsTab(
      {required this.db, required this.weekStart, required this.weekEnd});

  List<String> get _dateRange {
    final dates = <String>[];
    for (var i = 0; i <= 6; i++) {
      dates.add(
          DateFormat('yyyy-MM-dd').format(weekStart.add(Duration(days: i))));
    }
    return dates;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db
          .collection('checkins')
          .where('date', whereIn: _dateRange.take(10).toList())
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        // Sort by date desc then timestamp
        final sorted = [...docs];
        sorted.sort((a, b) {
          final aD = (a.data() as Map)['date'] as String? ?? '';
          final bD = (b.data() as Map)['date'] as String? ?? '';
          return bD.compareTo(aD);
        });

        if (sorted.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.how_to_reg_outlined,
                    size: 48, color: AppTheme.textHint),
                SizedBox(height: 12),
                Text('No check-ins this week',
                    style: TextStyle(color: AppTheme.textSecondary)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: sorted.length,
          itemBuilder: (_, i) {
            final d = sorted[i].data() as Map<String, dynamic>;
            final name = d['name'] as String? ?? '';
            final date = d['date'] as String? ?? '';
            final ts = d['timestamp'] != null
                ? DateTime.fromMillisecondsSinceEpoch(
                    (d['timestamp'] as dynamic).millisecondsSinceEpoch)
                : null;
            final hasOut = d['checkOutTime'] != null;
            final outTs = hasOut
                ? DateTime.fromMillisecondsSinceEpoch(
                    (d['checkOutTime'] as dynamic).millisecondsSinceEpoch)
                : null;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check,
                        color: AppTheme.success, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14)),
                        Text(
                          date,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textHint),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (ts != null)
                        Text(
                          'In: ${DateFormat('h:mm a').format(ts)}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.success),
                        ),
                      if (outTs != null)
                        Text(
                          'Out: ${DateFormat('h:mm a').format(outTs)}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.navy),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
