// lib/screens/volunteer/volunteer_schedule_screen.dart
// P1-1 + P2-7: Volunteer rotation schedule with "My Duties" personal filter tab.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_animations.dart';

class VolunteerScheduleScreen extends StatefulWidget {
  final UserModel user;
  const VolunteerScheduleScreen({super.key, required this.user});

  @override
  State<VolunteerScheduleScreen> createState() =>
      _VolunteerScheduleScreenState();
}

class _VolunteerScheduleScreenState extends State<VolunteerScheduleScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  List<Map<String, dynamic>> _weeks = [];
  List<_DutySlot> _myDuties = [];
  bool _loading = true;
  bool _uploading = false;
  String? _uploadMessage;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await Future.wait([
      _loadWeeks(),
      _loadMyDuties(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadWeeks() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('volunteer_rotations')
          .orderBy('publishedAt', descending: true)
          .limit(12)
          .get();
      _weeks = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (_) {
      _weeks = [];
    }
  }

  // P2-7: Load personal duties for next 8 weeks
  Future<void> _loadMyDuties() async {
    try {
      final myName = widget.user.displayName.toLowerCase();
      final snap = await FirebaseFirestore.instance
          .collection('volunteer_rotations')
          .orderBy('publishedAt', descending: true)
          .limit(8)
          .get();

      final duties = <_DutySlot>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        final slots = (data['slots'] as List?) ?? [];

        // Support both new 'slots' array format and legacy lunchSlots/recessSlots format
        if (slots.isNotEmpty) {
          for (final slot in slots) {
            if (slot is! Map) continue;
            final name = (slot['name'] as String? ?? '').toLowerCase();
            if (!name.contains(myName)) continue;

            final dateStr = slot['date'] as String?;
            DateTime? dutyDate;
            if (dateStr != null) {
              try {
                dutyDate = DateFormat('yyyy-MM-dd').parse(dateStr);
              } catch (_) {}
            }

            duties.add(_DutySlot(
              weekId: doc.id,
              weekLabel: data['weekLabel'] as String? ?? doc.id,
              dutyType: slot['type'] as String? ?? 'Duty',
              date: dutyDate,
              partners: slots
                  .where((s) =>
                      s is Map &&
                      (s['date'] as String?) == dateStr &&
                      (s['name'] as String? ?? '').toLowerCase() != myName)
                  .map((s) => s['name'] as String? ?? '')
                  .toList(),
            ));
          }
        } else {
          // Legacy format: check lunchSlots, recessSlots
          final lunchSlots =
              (data['lunchSlots'] as Map<String, dynamic>?) ?? {};
          final recessSlots =
              (data['recessSlots'] as Map<String, dynamic>?) ?? {};

          lunchSlots.forEach((day, names) {
            if (names is List &&
                names.any((n) =>
                    n.toString().toLowerCase().contains(myName))) {
              duties.add(_DutySlot(
                weekId: doc.id,
                weekLabel: data['weekLabel'] as String? ?? doc.id,
                dutyType: 'Lunch',
                date: null,
                dayLabel: _dayLabel(day),
                partners: names
                    .where((n) =>
                        !n.toString().toLowerCase().contains(myName))
                    .map((n) => n.toString())
                    .toList(),
              ));
            }
          });

          recessSlots.forEach((day, names) {
            if (names is List &&
                names.any((n) =>
                    n.toString().toLowerCase().contains(myName))) {
              duties.add(_DutySlot(
                weekId: doc.id,
                weekLabel: data['weekLabel'] as String? ?? doc.id,
                dutyType: 'Recess',
                date: null,
                dayLabel: _dayLabel(day),
                partners: names
                    .where((n) =>
                        !n.toString().toLowerCase().contains(myName))
                    .map((n) => n.toString())
                    .toList(),
              ));
            }
          });
        }
      }

      // Sort by date (null dates go to end)
      duties.sort((a, b) {
        if (a.date == null && b.date == null) return 0;
        if (a.date == null) return 1;
        if (b.date == null) return -1;
        return a.date!.compareTo(b.date!);
      });

      _myDuties = duties;
    } catch (_) {
      _myDuties = [];
    }
  }

  String _dayLabel(String day) {
    const labels = {
      'mon': 'Monday',
      'tue': 'Tuesday',
      'wed': 'Wednesday',
      'thu': 'Thursday',
      'fri': 'Friday',
    };
    return labels[day] ?? day;
  }

  // ── Admin: CSV upload ────────────────────────────────────────────────────
  Future<void> _uploadCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.first.bytes;
    if (bytes == null) return;

    final csv = String.fromCharCodes(bytes);
    final rows = csv.split('\n').skip(1);

    setState(() {
      _uploading = true;
      _uploadMessage = null;
    });

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      int count = 0;

      for (final row in rows) {
        final cols = row.trim().split(',');
        if (cols.length < 4) continue;

        final weekId = cols[0].trim();
        final day = cols[1].trim().toLowerCase();
        final dutyType = cols[2].trim().toLowerCase();
        final names = cols[3].trim().split(';').map((n) => n.trim()).toList();

        final validWeekId = RegExp(r'^\d{4}-W\d{2}$').hasMatch(weekId);
        final validDay = ['mon', 'tue', 'wed', 'thu', 'fri'].contains(day);
        final validDuty =
            ['lunch', 'recess', 'thursday_extra'].contains(dutyType);
        if (!validWeekId || !validDay || !validDuty) continue;

        final ref = db.collection('volunteer_rotations').doc(weekId);
        if (dutyType == 'lunch') {
          batch.set(ref,
              {'lunchSlots.$day': names, 'publishedAt': FieldValue.serverTimestamp()},
              SetOptions(merge: true));
        } else if (dutyType == 'recess') {
          batch.set(ref,
              {'recessSlots.$day': names, 'publishedAt': FieldValue.serverTimestamp()},
              SetOptions(merge: true));
        } else if (dutyType == 'thursday_extra') {
          batch.set(ref,
              {'thursdayExtra': names, 'publishedAt': FieldValue.serverTimestamp()},
              SetOptions(merge: true));
        }
        count++;
      }

      await batch.commit();
      setState(() {
        _uploadMessage = '✅ $count rows imported successfully';
        _uploading = false;
      });
      await _loadAll();
    } catch (e) {
      setState(() {
        _uploadMessage = '❌ Import failed: $e';
        _uploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        title: const Text('Volunteer Schedule',
            style: TextStyle(fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppTheme.gold,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'All Schedule'),
            Tab(text: 'My Duties'),
          ],
        ),
      ),
      floatingActionButton: widget.user.isAdmin
          ? FloatingActionButton.extended(
              onPressed: _uploading ? null : _uploadCsv,
              backgroundColor: AppTheme.navy,
              foregroundColor: Colors.white,
              icon: _uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.upload_file_outlined),
              label: Text(_uploading ? 'Uploading…' : 'Upload CSV'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_uploadMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    color: _uploadMessage!.startsWith('✅')
                        ? Colors.green[50]
                        : Colors.red[50],
                    child: Text(_uploadMessage!,
                        style: TextStyle(
                          color: _uploadMessage!.startsWith('✅')
                              ? Colors.green[800]
                              : Colors.red[800],
                          fontSize: 13,
                        )),
                  ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      // Tab 1: All Schedule
                      _AllScheduleTab(weeks: _weeks),
                      // Tab 2: My Duties
                      _MyDutiesTab(
                          duties: _myDuties,
                          userName: widget.user.displayName),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ── All Schedule Tab ─────────────────────────────────────────────────────────
class _AllScheduleTab extends StatelessWidget {
  final List<Map<String, dynamic>> weeks;
  const _AllScheduleTab({required this.weeks});

  @override
  Widget build(BuildContext context) {
    if (weeks.isEmpty) {
      return const Center(
          child: Text('No rotation data posted yet.',
              style: TextStyle(color: Colors.black45)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: weeks.length,
      itemBuilder: (context, i) =>
          _WeekExpansionTile(weekData: weeks[i], index: i),
    );
  }
}

// ── My Duties Tab ─────────────────────────────────────────────────────────────
class _MyDutiesTab extends StatelessWidget {
  final List<_DutySlot> duties;
  final String userName;
  const _MyDutiesTab({required this.duties, required this.userName});

  @override
  Widget build(BuildContext context) {
    if (duties.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_available_outlined,
                size: 52, color: AppTheme.textTertiary),
            const SizedBox(height: 16),
            const Text('You have no upcoming duties scheduled.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: duties.length,
      itemBuilder: (context, i) {
        final duty = duties[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.calendarColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.volunteer_activism,
                      color: AppTheme.calendarColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        duty.date != null
                            ? DateFormat('EEEE, MMM d').format(duty.date!)
                            : '${duty.weekLabel} · ${duty.dayLabel ?? ''}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.navyDark),
                      ),
                      Text(duty.dutyType,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13)),
                      if (duty.partners.isNotEmpty)
                        Text('With: ${duty.partners.join(', ')}',
                            style: const TextStyle(
                                color: AppTheme.textTertiary,
                                fontSize: 12,
                                fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )
            .animate(
                delay: AppAnimations.staggerItemDelay * i)
            .fadeIn()
            .moveY(
                begin: 8,
                end: 0,
                duration: AppAnimations.cardFadeInDuration);
      },
    );
  }
}

// ── Data Classes ──────────────────────────────────────────────────────────────
class _DutySlot {
  final String weekId;
  final String weekLabel;
  final String dutyType;
  final DateTime? date;
  final String? dayLabel;
  final List<String> partners;

  const _DutySlot({
    required this.weekId,
    required this.weekLabel,
    required this.dutyType,
    required this.date,
    this.dayLabel,
    required this.partners,
  });
}

// ── Week Expansion Tile (All Schedule tab) ────────────────────────────────────
class _WeekExpansionTile extends StatelessWidget {
  final Map<String, dynamic> weekData;
  final int index;
  const _WeekExpansionTile({required this.weekData, required this.index});

  @override
  Widget build(BuildContext context) {
    final weekId = weekData['id'] as String? ?? '';
    final weekLabel = weekData['weekLabel'] as String? ?? weekId;
    final notes = weekData['notes'] as String?;
    final lunchSlots = (weekData['lunchSlots'] as Map<String, dynamic>?) ?? {};
    final recessSlots =
        (weekData['recessSlots'] as Map<String, dynamic>?) ?? {};
    final thursdayExtra =
        List<String>.from(weekData['thursdayExtra'] as List? ?? []);

    const days = ['mon', 'tue', 'wed', 'thu', 'fri'];
    const dayLabels = {
      'mon': 'Monday',
      'tue': 'Tuesday',
      'wed': 'Wednesday',
      'thu': 'Thursday',
      'fri': 'Friday',
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(weekLabel,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: notes != null
            ? Text(notes,
                style: const TextStyle(fontSize: 12, color: Colors.black54))
            : null,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: days.map((day) {
                final lunch =
                    List<String>.from(lunchSlots[day] as List? ?? []);
                final recess =
                    List<String>.from(recessSlots[day] as List? ?? []);
                final hasThursday =
                    day == 'thu' && thursdayExtra.isNotEmpty;

                if (lunch.isEmpty && recess.isEmpty && !hasThursday) {
                  return const SizedBox.shrink();
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dayLabels[day]!,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppTheme.navy)),
                    if (lunch.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 12, top: 4),
                        child: Text('Lunch: ${lunch.join(', ')}',
                            style: const TextStyle(fontSize: 12)),
                      ),
                    if (recess.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 12, top: 2),
                        child: Text('Recess: ${recess.join(', ')}',
                            style: const TextStyle(fontSize: 12)),
                      ),
                    if (hasThursday)
                      Padding(
                        padding: const EdgeInsets.only(left: 12, top: 2),
                        child: Text(
                            'Special: ${thursdayExtra.join(', ')}',
                            style: const TextStyle(fontSize: 12)),
                      ),
                    const SizedBox(height: 6),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    )
        .animate(delay: AppAnimations.staggerItemDelay * index)
        .fadeIn()
        .moveY(
          begin: 8,
          end: 0,
          duration: AppAnimations.cardFadeInDuration,
        );
  }
}
