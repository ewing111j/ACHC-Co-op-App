// lib/screens/admin/admin_analytics_screen.dart
//
// P3-3: Co-op Analytics Dashboard (Admin only)
//
// Tabs:
//   1. Memory Work  — WP earned per week (bar), mastery distribution (pie)
//   2. Volunteer    — slot fill-rate per week (bar), uncovered duties list
//   3. Attendance   — check-in counts per co-op day (bar)
//   4. Participation — recite attempts and pass rates (bar)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../utils/app_theme.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  static const _purple = Color(0xFF7B1FA2);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Co-op Analytics'),
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppTheme.gold,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle:
              const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(icon: Icon(Icons.psychology_outlined, size: 18), text: 'Memory'),
            Tab(icon: Icon(Icons.volunteer_activism_outlined, size: 18), text: 'Volunteer'),
            Tab(icon: Icon(Icons.how_to_reg_outlined, size: 18), text: 'Attendance'),
            Tab(icon: Icon(Icons.bar_chart_outlined, size: 18), text: 'Participation'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _MemoryTab(db: _db),
          _VolunteerTab(db: _db),
          _AttendanceTab(db: _db),
          _ParticipationTab(db: _db),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 1 — Memory Work
// ══════════════════════════════════════════════════════════════════════════════

class _MemoryTab extends StatelessWidget {
  final FirebaseFirestore db;
  const _MemoryTab({required this.db});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.emoji_events_outlined,
            title: 'WP Earned — Last 8 Weeks',
            color: AppTheme.gold,
          ),
          const SizedBox(height: 12),
          _WpWeeklyChart(db: db),
          const SizedBox(height: 24),
          _SectionHeader(
            icon: Icons.pie_chart_outline,
            title: 'Mastery Distribution',
            color: AppTheme.navy,
          ),
          const SizedBox(height: 12),
          _MasteryPieChart(db: db),
          const SizedBox(height: 24),
          _SectionHeader(
            icon: Icons.people_outline,
            title: 'Top Students (WP)',
            color: const Color(0xFF7B1FA2),
          ),
          const SizedBox(height: 12),
          _TopStudentsList(db: db),
        ],
      ),
    );
  }
}

class _WpWeeklyChart extends StatefulWidget {
  final FirebaseFirestore db;
  const _WpWeeklyChart({required this.db});

  @override
  State<_WpWeeklyChart> createState() => _WpWeeklyChartState();
}

class _WpWeeklyChartState extends State<_WpWeeklyChart> {
  bool _loading = true;
  List<BarChartGroupData> _bars = [];
  List<String> _labels = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final weekTotals = <String, int>{};
    final weekLabels = <String>[];

    // Build 8-week buckets
    for (int i = 7; i >= 0; i--) {
      final weekStart = now.subtract(Duration(days: now.weekday - 1 + i * 7));
      final label = DateFormat('MM/dd').format(weekStart);
      weekLabels.add(label);
      weekTotals[label] = 0;
    }

    try {
      final cutoff = Timestamp.fromDate(now.subtract(const Duration(days: 56)));
      final snap = await widget.db
          .collection('lumen_state')
          .where('updatedAt', isGreaterThan: cutoff)
          .get();

      for (final doc in snap.docs) {
        final data = doc.data();
        final ts = data['updatedAt'];
        if (ts is! Timestamp) continue;
        final date = ts.toDate();
        final weekStart = date.subtract(Duration(days: date.weekday - 1));
        final label = DateFormat('MM/dd').format(weekStart);
        final wp = (data['total_wp'] as num?)?.toInt() ?? 0;
        // Approximate weekly WP by counting docs updated that week
        // (precise weekly delta would need history sub-collection)
        if (weekTotals.containsKey(label)) {
          weekTotals[label] = (weekTotals[label] ?? 0) + wp;
        }
      }
    } catch (_) {
      // graceful — show zeros
    }

    final bars = <BarChartGroupData>[];
    for (int i = 0; i < weekLabels.length; i++) {
      final val = (weekTotals[weekLabels[i]] ?? 0).toDouble();
      bars.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: val,
              color: AppTheme.gold,
              width: 18,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }

    if (mounted) {
      setState(() {
        _bars = bars;
        _labels = weekLabels;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _ChartLoader();
    if (_bars.isEmpty) return const _EmptyChart();

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          barGroups: _bars,
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= _labels.length) return const SizedBox();
                  return Text(
                    _labels[i],
                    style: const TextStyle(fontSize: 9),
                  );
                },
                reservedSize: 22,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (v, _) => Text(
                  v.toInt().toString(),
                  style: const TextStyle(fontSize: 9),
                ),
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: true),
        ),
      ),
    );
  }
}

class _MasteryPieChart extends StatefulWidget {
  final FirebaseFirestore db;
  const _MasteryPieChart({required this.db});

  @override
  State<_MasteryPieChart> createState() => _MasteryPieChartState();
}

class _MasteryPieChartState extends State<_MasteryPieChart> {
  bool _loading = true;
  int _heard = 0, _getting = 0, _got = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snap =
          await widget.db.collectionGroup('progress').limit(500).get();
      int h = 0, g = 0, gt = 0;
      for (final doc in snap.docs) {
        final lvl = (doc.data()['mastery_level'] as num?)?.toInt() ?? 0;
        if (lvl == 1) h++;
        if (lvl == 2) g++;
        if (lvl == 3) gt++;
      }
      if (mounted) setState(() {
        _heard = h; _getting = g; _got = gt; _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _ChartLoader();
    final total = _heard + _getting + _got;
    if (total == 0) return const _EmptyChart();

    return Row(
      children: [
        SizedBox(
          width: 140,
          height: 140,
          child: PieChart(
            PieChartData(
              sections: [
                PieChartSectionData(
                  value: _heard.toDouble(),
                  color: Colors.red[300]!,
                  title: '$_heard',
                  radius: 50,
                  titleStyle: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                PieChartSectionData(
                  value: _getting.toDouble(),
                  color: Colors.orange[300]!,
                  title: '$_getting',
                  radius: 50,
                  titleStyle: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                PieChartSectionData(
                  value: _got.toDouble(),
                  color: Colors.green[400]!,
                  title: '$_got',
                  radius: 50,
                  titleStyle: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ],
              sectionsSpace: 2,
            ),
          ),
        ),
        const SizedBox(width: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Legend(color: Colors.red[300]!, label: '🌱 Just Heard It', count: _heard),
            const SizedBox(height: 8),
            _Legend(color: Colors.orange[300]!, label: '🔥 Getting There', count: _getting),
            const SizedBox(height: 8),
            _Legend(color: Colors.green[400]!, label: '⭐ Got It', count: _got),
          ],
        ),
      ],
    );
  }
}

class _TopStudentsList extends StatefulWidget {
  final FirebaseFirestore db;
  const _TopStudentsList({required this.db});

  @override
  State<_TopStudentsList> createState() => _TopStudentsListState();
}

class _TopStudentsListState extends State<_TopStudentsList> {
  bool _loading = true;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snap = await widget.db
          .collection('lumen_state')
          .orderBy('total_wp', descending: true)
          .limit(10)
          .get();
      final rows = <Map<String, dynamic>>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        final uid = doc.id;
        // Resolve name
        String name = data['displayName'] as String? ?? '';
        if (name.isEmpty) {
          try {
            final userDoc =
                await widget.db.collection('users').doc(uid).get();
            name = userDoc.data()?['displayName'] as String? ?? uid;
          } catch (_) {
            name = uid;
          }
        }
        rows.add({
          'name': name,
          'total_wp': (data['total_wp'] as num?)?.toInt() ?? 0,
          'lumen_level': (data['lumen_level'] as num?)?.toInt() ?? 1,
        });
      }
      if (mounted) setState(() { _rows = rows; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _ChartLoader();
    if (_rows.isEmpty) return const _EmptyChart();
    return Column(
      children: _rows.asMap().entries.map((e) {
        final rank = e.key + 1;
        final row = e.value;
        return ListTile(
          dense: true,
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.gold.withValues(alpha: 0.2),
            child: Text('$rank',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.gold.withValues(alpha: 1.0))),
          ),
          title: Text(row['name'] as String,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          trailing: Text(
            '${row['total_wp']} WP',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.gold.withValues(alpha: 1.0)),
          ),
        );
      }).toList(),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — Volunteer Coverage
// ══════════════════════════════════════════════════════════════════════════════

class _VolunteerTab extends StatelessWidget {
  final FirebaseFirestore db;
  const _VolunteerTab({required this.db});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.event_available_outlined,
            title: 'Slot Fill Rate — Recent Weeks',
            color: AppTheme.calendarColor,
          ),
          const SizedBox(height: 12),
          _FillRateChart(db: db),
          const SizedBox(height: 24),
          _SectionHeader(
            icon: Icons.warning_amber_outlined,
            title: 'Uncovered Duties',
            color: Colors.orange,
          ),
          const SizedBox(height: 12),
          _UncoveredList(db: db),
        ],
      ),
    );
  }
}

class _FillRateChart extends StatefulWidget {
  final FirebaseFirestore db;
  const _FillRateChart({required this.db});

  @override
  State<_FillRateChart> createState() => _FillRateChartState();
}

class _FillRateChartState extends State<_FillRateChart> {
  bool _loading = true;
  List<BarChartGroupData> _bars = [];
  List<String> _labels = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snap = await widget.db
          .collection('volunteer_rotations')
          .orderBy('publishedAt', descending: true)
          .limit(8)
          .get();

      final bars = <BarChartGroupData>[];
      final labels = <String>[];

      for (int i = 0; i < snap.docs.length; i++) {
        final data = snap.docs[i].data();
        final weekId = data['weekId'] as String? ?? '?';
        labels.add(weekId.length > 6 ? weekId.substring(0, 6) : weekId);

        // Count filled vs total slots
        int filled = 0, total = 0;
        final slots = data['slots'] as List<dynamic>? ?? [];
        for (final slot in slots) {
          if (slot is Map) {
            total++;
            if ((slot['assignedTo'] as String? ?? '').isNotEmpty) filled++;
          }
        }
        final rate = total > 0 ? (filled / total * 100) : 0.0;

        bars.add(
          BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: rate,
                color: rate >= 90
                    ? Colors.green
                    : rate >= 70
                        ? Colors.orange
                        : Colors.red,
                width: 18,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        );
      }

      if (mounted) {
        setState(() {
          _bars = bars.reversed.toList();
          _labels = labels.reversed.toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _ChartLoader();
    if (_bars.isEmpty) return const _EmptyChart();

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          maxY: 100,
          barGroups: _bars,
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= _labels.length) return const SizedBox();
                  return Text(_labels[i],
                      style: const TextStyle(fontSize: 9));
                },
                reservedSize: 22,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (v, _) => Text('${v.toInt()}%',
                    style: const TextStyle(fontSize: 9)),
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: true),
        ),
      ),
    );
  }
}

class _UncoveredList extends StatefulWidget {
  final FirebaseFirestore db;
  const _UncoveredList({required this.db});

  @override
  State<_UncoveredList> createState() => _UncoveredListState();
}

class _UncoveredListState extends State<_UncoveredList> {
  bool _loading = true;
  List<Map<String, String>> _uncovered = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snap = await widget.db
          .collection('volunteer_rotations')
          .orderBy('publishedAt', descending: true)
          .limit(4)
          .get();

      final list = <Map<String, String>>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        final weekId = data['weekId'] as String? ?? '?';
        final slots = data['slots'] as List<dynamic>? ?? [];
        for (final slot in slots) {
          if (slot is Map) {
            final assigned = slot['assignedTo'] as String? ?? '';
            if (assigned.isEmpty) {
              list.add({
                'week': weekId,
                'duty': slot['duty'] as String? ?? 'Unknown duty',
                'day': slot['day'] as String? ?? '',
              });
            }
          }
        }
      }
      if (mounted) setState(() { _uncovered = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _ChartLoader();
    if (_uncovered.isEmpty) {
      return const _InfoCard(
        icon: Icons.check_circle_outline,
        message: 'All recent slots are covered!',
        color: Colors.green,
      );
    }
    return Column(
      children: _uncovered.map((item) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.warning_amber_outlined,
                color: Colors.orange, size: 20),
            title: Text(item['duty'] ?? '',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text('${item['week']}  •  ${item['day']}',
                style: const TextStyle(fontSize: 11)),
            trailing: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Unfilled',
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.orange,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — Attendance
// ══════════════════════════════════════════════════════════════════════════════

class _AttendanceTab extends StatelessWidget {
  final FirebaseFirestore db;
  const _AttendanceTab({required this.db});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.how_to_reg_outlined,
            title: 'Check-Ins — Last 8 Co-op Days',
            color: AppTheme.checkInColor,
          ),
          const SizedBox(height: 12),
          _CheckInChart(db: db),
          const SizedBox(height: 24),
          _SectionHeader(
            icon: Icons.person_off_outlined,
            title: 'Recent Absences',
            color: Colors.red,
          ),
          const SizedBox(height: 12),
          _AbsenceList(db: db),
        ],
      ),
    );
  }
}

class _CheckInChart extends StatefulWidget {
  final FirebaseFirestore db;
  const _CheckInChart({required this.db});

  @override
  State<_CheckInChart> createState() => _CheckInChartState();
}

class _CheckInChartState extends State<_CheckInChart> {
  bool _loading = true;
  List<BarChartGroupData> _bars = [];
  List<String> _labels = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // Get unique dates from checkins
      final snap = await FirebaseFirestore.instance
          .collection('checkins')
          .orderBy('date', descending: true)
          .limit(200)
          .get();

      final dateCounts = <String, int>{};
      for (final doc in snap.docs) {
        final date = doc.data()['date'] as String? ?? '';
        if (date.isNotEmpty) {
          dateCounts[date] = (dateCounts[date] ?? 0) + 1;
        }
      }

      final sorted = dateCounts.keys.toList()..sort();
      final recent = sorted.reversed.take(8).toList().reversed.toList();

      final bars = <BarChartGroupData>[];
      final labels = <String>[];

      for (int i = 0; i < recent.length; i++) {
        final date = recent[i];
        final count = dateCounts[date] ?? 0;
        labels.add(date.length >= 5 ? date.substring(5) : date); // MM-DD
        bars.add(
          BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: count.toDouble(),
                color: AppTheme.checkInColor,
                width: 18,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        );
      }

      if (mounted) setState(() {
        _bars = bars; _labels = labels; _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _ChartLoader();
    if (_bars.isEmpty) return const _EmptyChart();

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          barGroups: _bars,
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= _labels.length) return const SizedBox();
                  return Text(_labels[i],
                      style: const TextStyle(fontSize: 9));
                },
                reservedSize: 22,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                    style: const TextStyle(fontSize: 9)),
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: true),
        ),
      ),
    );
  }
}

class _AbsenceList extends StatefulWidget {
  final FirebaseFirestore db;
  const _AbsenceList({required this.db});

  @override
  State<_AbsenceList> createState() => _AbsenceListState();
}

class _AbsenceListState extends State<_AbsenceList> {
  bool _loading = true;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snap = await widget.db
          .collection('absences')
          .orderBy('date', descending: true)
          .limit(10)
          .get();
      if (mounted) setState(() {
        _rows = snap.docs.map((d) => d.data()).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _ChartLoader();
    if (_rows.isEmpty) {
      return const _InfoCard(
          icon: Icons.celebration_outlined,
          message: 'No absences recorded recently.',
          color: Colors.green);
    }
    return Column(
      children: _rows.map((row) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.person_off_outlined,
                color: Colors.red, size: 20),
            title: Text(row['studentName'] as String? ?? 'Unknown',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text(row['reason'] as String? ?? '',
                style: const TextStyle(fontSize: 11)),
            trailing: Text(row['date'] as String? ?? '',
                style:
                    const TextStyle(fontSize: 11, color: Colors.grey)),
          ),
        );
      }).toList(),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 4 — Participation (Recite Check stats)
// ══════════════════════════════════════════════════════════════════════════════

class _ParticipationTab extends StatelessWidget {
  final FirebaseFirestore db;
  const _ParticipationTab({required this.db});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.record_voice_over_outlined,
            title: 'Recite Attempts — Last 8 Weeks',
            color: AppTheme.navy,
          ),
          const SizedBox(height: 12),
          _ReciteAttemptsChart(db: db),
          const SizedBox(height: 24),
          _SectionHeader(
            icon: Icons.military_tech_outlined,
            title: 'Battle Pass Rates',
            color: AppTheme.gold,
          ),
          const SizedBox(height: 12),
          _BattleStatsCard(db: db),
        ],
      ),
    );
  }
}

class _ReciteAttemptsChart extends StatefulWidget {
  final FirebaseFirestore db;
  const _ReciteAttemptsChart({required this.db});

  @override
  State<_ReciteAttemptsChart> createState() => _ReciteAttemptsChartState();
}

class _ReciteAttemptsChartState extends State<_ReciteAttemptsChart> {
  bool _loading = true;
  List<BarChartGroupData> _bars = [];
  List<String> _labels = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Recite attempts are stored as progress updates with mastery 2-3
    // grouped by week — approximate from progress sub-collections
    final now = DateTime.now();
    final weekLabels = <String>[];
    final counts = <int>[];

    for (int i = 7; i >= 0; i--) {
      final weekStart = now.subtract(Duration(days: now.weekday - 1 + i * 7));
      weekLabels.add(DateFormat('MM/dd').format(weekStart));
      counts.add(0);
    }

    try {
      final cutoff = Timestamp.fromDate(now.subtract(const Duration(days: 56)));
      final snap = await widget.db
          .collectionGroup('progress')
          .where('lastPracticed', isGreaterThan: cutoff)
          .limit(1000)
          .get();

      for (final doc in snap.docs) {
        final ts = doc.data()['lastPracticed'];
        if (ts is! Timestamp) continue;
        final date = ts.toDate();
        final weekIdx = ((now.difference(date).inDays) / 7).floor();
        if (weekIdx >= 0 && weekIdx < 8) {
          counts[7 - weekIdx]++;
        }
      }
    } catch (_) {
      // no data yet
    }

    final bars = <BarChartGroupData>[];
    for (int i = 0; i < weekLabels.length; i++) {
      bars.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: counts[i].toDouble(),
              color: AppTheme.navy,
              width: 18,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }

    if (mounted) setState(() {
      _bars = bars; _labels = weekLabels; _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _ChartLoader();
    if (_bars.every((b) => b.barRods.first.toY == 0)) return const _EmptyChart();

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          barGroups: _bars,
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= _labels.length) return const SizedBox();
                  return Text(_labels[i],
                      style: const TextStyle(fontSize: 9));
                },
                reservedSize: 22,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                    style: const TextStyle(fontSize: 9)),
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: true),
        ),
      ),
    );
  }
}

class _BattleStatsCard extends StatefulWidget {
  final FirebaseFirestore db;
  const _BattleStatsCard({required this.db});

  @override
  State<_BattleStatsCard> createState() => _BattleStatsCardState();
}

class _BattleStatsCardState extends State<_BattleStatsCard> {
  bool _loading = true;
  int _total = 0, _victories = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snap = await widget.db
          .collection('battle_results')
          .limit(500)
          .get();
      int total = 0, victories = 0;
      for (final doc in snap.docs) {
        total++;
        if (doc.data()['won'] == true) victories++;
      }
      if (mounted) setState(() {
        _total = total; _victories = victories; _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _ChartLoader();

    final rate = _total > 0
        ? (_victories / _total * 100).toStringAsFixed(1)
        : '—';

    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.sports_kabaddi_outlined,
            label: 'Total Battles',
            value: '$_total',
            color: AppTheme.navy,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            icon: Icons.emoji_events_outlined,
            label: 'Victories',
            value: '$_victories',
            color: AppTheme.gold,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            icon: Icons.percent_outlined,
            label: 'Win Rate',
            value: '$rate%',
            color: Colors.green,
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Shared helper widgets
// ══════════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  const _SectionHeader({required this.icon, required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  const _Legend({required this.color, required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 14, height: 14,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text('$label ($count)',
            style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatTile({required this.icon, required this.label,
      required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: AppTheme.textSecondary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ChartLoader extends StatelessWidget {
  const _ChartLoader();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 120,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      alignment: Alignment.center,
      child: Text('No data yet',
          style: TextStyle(color: Colors.grey[400], fontSize: 13)),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;
  const _InfoCard({required this.icon, required this.message, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message,
              style: TextStyle(fontSize: 13, color: color))),
        ],
      ),
    );
  }
}
