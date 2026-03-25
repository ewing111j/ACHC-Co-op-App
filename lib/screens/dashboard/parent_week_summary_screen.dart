// lib/screens/dashboard/parent_week_summary_screen.dart
// P2-6: Parent "My Week" summary — children's Memory Work + volunteer duties + class schedule.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../models/memory/memory_models.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_animations.dart';
import '../../utils/week_utils.dart';

class ParentWeekSummaryScreen extends StatefulWidget {
  final UserModel user;
  const ParentWeekSummaryScreen({super.key, required this.user});

  @override
  State<ParentWeekSummaryScreen> createState() =>
      _ParentWeekSummaryScreenState();
}

class _ParentWeekSummaryScreenState extends State<ParentWeekSummaryScreen> {
  final _db = FirebaseFirestore.instance;

  DateTime _weekRef = DateTime.now();
  bool _loading = true;

  // Data
  List<_ChildProgress> _childProgress = [];
  List<Map<String, dynamic>> _volunteerDuties = [];
  List<Map<String, dynamic>> _classSlots = [];
  Map<String, dynamic>? _nextWeekPreview;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await Future.wait([
      _loadChildProgress(),
      _loadVolunteerDuties(),
      _loadClassSchedule(),
      _loadNextWeekPreview(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  // ── Children Memory Work progress ─────────────────────────────────────────
  Future<void> _loadChildProgress() async {
    if (widget.user.kidUids.isEmpty) {
      _childProgress = [];
      return;
    }

    final progress = <_ChildProgress>[];
    final weekStart = WeekUtils.weekStart(_weekRef);
    final weekEnd = WeekUtils.weekEnd(_weekRef).add(const Duration(days: 1));

    for (final kidUid in widget.user.kidUids) {
      try {
        // Get kid's display name
        final kidDoc = await _db.collection('users').doc(kidUid).get();
        final kidName = (kidDoc.data()?['displayName'] as String?) ?? kidUid;

        // Get subjects for current cycle
        final subjectsSnap =
            await _db.collection('subjects').limit(12).get();
        final subjects = subjectsSnap.docs
            .map((d) => SubjectModel.fromMap(d.id, d.data()))
            .toList();

        // Get student_progress practiced this week
        final progressSnap = await _db
            .collection('student_progress')
            .where('student_id', isEqualTo: kidUid)
            .get();

        final practicedThisWeek = <String>{};
        for (final doc in progressSnap.docs) {
          final lastPracticed = doc.data()['last_practiced'];
          if (lastPracticed is Timestamp) {
            final dt = lastPracticed.toDate();
            if (dt.isAfter(weekStart) && dt.isBefore(weekEnd)) {
              practicedThisWeek.add(doc.data()['subject_id'] as String? ?? '');
            }
          }
        }

        progress.add(_ChildProgress(
          uid: kidUid,
          name: kidName,
          subjects: subjects,
          practicedSubjectIds: practicedThisWeek,
        ));
      } catch (_) {
        // Skip failed child
      }
    }
    _childProgress = progress;
  }

  // ── Volunteer Duties ──────────────────────────────────────────────────────
  Future<void> _loadVolunteerDuties() async {
    try {
      final weekStart = WeekUtils.weekStart(_weekRef);
      final weekEnd = WeekUtils.weekEnd(_weekRef);
      final myName = widget.user.displayName.toLowerCase();

      final snap = await _db
          .collection('volunteer_rotations')
          .orderBy('publishedAt', descending: true)
          .limit(4)
          .get();

      final duties = <Map<String, dynamic>>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        final slots = (data['slots'] as List?) ?? [];
        for (final slot in slots) {
          if (slot is! Map) continue;
          final name = (slot['name'] as String? ?? '').toLowerCase();
          final dateStr = slot['date'] as String?;
          if (!name.contains(myName)) continue;
          if (dateStr != null) {
            try {
              final dt = DateFormat('yyyy-MM-dd').parse(dateStr);
              if (dt.isAfter(weekStart.subtract(const Duration(days: 1))) &&
                  dt.isBefore(weekEnd.add(const Duration(days: 1)))) {
                duties.add({
                  'date': dt,
                  'type': slot['type'] ?? 'Duty',
                  'partners': slots
                      .where((s) =>
                          s is Map &&
                          (s['date'] as String?) == dateStr &&
                          (s['name'] as String? ?? '').toLowerCase() !=
                              myName)
                      .map((s) => s['name'] as String? ?? '')
                      .toList(),
                });
              }
            } catch (_) {}
          }
        }
      }
      _volunteerDuties = duties;
    } catch (_) {
      _volunteerDuties = [];
    }
  }

  // ── Class Schedule ────────────────────────────────────────────────────────
  Future<void> _loadClassSchedule() async {
    try {
      final snap = await _db
          .collection('classes')
          .where('student_uids', arrayContains: widget.user.uid)
          .get();

      // Also include classes where user is a mentor
      QuerySnapshot<Map<String, dynamic>>? mentorSnap;
      if (widget.user.mentorClassIds.isNotEmpty) {
        mentorSnap = await _db
            .collection('classes')
            .where(FieldPath.documentId,
                whereIn: widget.user.mentorClassIds.take(10).toList())
            .get();
      }

      final allDocs = [
        ...snap.docs,
        ...?mentorSnap?.docs,
      ];

      _classSlots = allDocs
          .map((d) => {
                'name': d.data()['name'] ?? 'Class',
                'schedule': d.data()['schedule'] ?? '',
                'classId': d.id,
              })
          .toList();
    } catch (_) {
      _classSlots = [];
    }
  }

  // ── Next Week Preview ─────────────────────────────────────────────────────
  Future<void> _loadNextWeekPreview() async {
    try {
      final snap = await _db
          .collection('memory_settings')
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        final currentUnit = (data['current_unit'] as int?) ?? 1;
        _nextWeekPreview = {
          'unit': currentUnit + 1,
          'cycleId': data['active_cycle_id'] ?? 'cycle_2',
        };
      }
    } catch (_) {
      _nextWeekPreview = null;
    }
  }

  // ── Share Export ──────────────────────────────────────────────────────────
  void _share() {
    final buf = StringBuffer();
    buf.writeln('── ACHC Week Summary: ${WeekUtils.weekLabel(_weekRef)} ──');
    buf.writeln();

    if (_childProgress.isNotEmpty) {
      buf.writeln("Children's Memory Work:");
      for (final child in _childProgress) {
        final practiced = child.practicedSubjectIds.length;
        final total = child.subjects.length;
        buf.write('  ${child.name}: ');
        buf.writeln('$practiced / $total subjects practiced');
        for (final s in child.subjects) {
          final done = child.practicedSubjectIds.contains(s.id);
          buf.writeln('    ${done ? '✓' : '○'} ${s.name}');
        }
      }
      buf.writeln();
    }

    if (_volunteerDuties.isNotEmpty) {
      buf.writeln('Volunteer Duties:');
      for (final d in _volunteerDuties) {
        final dt = d['date'] as DateTime;
        buf.writeln('  ${DateFormat('EEEE, MMM d').format(dt)}: ${d['type']}');
      }
      buf.writeln();
    }

    if (_classSlots.isNotEmpty) {
      buf.writeln('Classes This Week:');
      for (final c in _classSlots) {
        buf.writeln('  ${c['name']}  ${c['schedule']}');
      }
      buf.writeln();
    }

    if (_nextWeekPreview != null) {
      buf.writeln('Coming Up Next Week:');
      buf.writeln('  Memory Work Unit ${_nextWeekPreview!['unit']}');
    }

    Share.share(buf.toString(), subject: 'ACHC Week Summary');
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.navyDark,
        foregroundColor: Colors.white,
        title: const Text('My Week Summary',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share summary',
            onPressed: _loading ? null : _share,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _share,
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.share_outlined),
        label: const Text('Share Week Summary'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  // ── Week Header ─────────────────────────────────────────
                  _WeekHeader(weekRef: _weekRef, onWeekChanged: (d) {
                    setState(() => _weekRef = d);
                    _load();
                  }).animate().fadeIn(duration: AppAnimations.cardFadeInDuration),

                  const SizedBox(height: 16),

                  // ── Children's Memory Work ───────────────────────────────
                  if (_childProgress.isNotEmpty) ...[
                    _sectionHeader(
                        "Children's Memory Work", Icons.auto_stories_outlined),
                    const SizedBox(height: 8),
                    ..._childProgress.asMap().entries.map((e) {
                      final i = e.key;
                      final child = e.value;
                      return _ChildProgressCard(child: child)
                          .animate()
                          .fadeIn(
                            duration: AppAnimations.cardFadeInDuration,
                            delay: Duration(
                                milliseconds:
                                    i * AppAnimations.staggerItemDelay.inMilliseconds),
                          )
                          .moveY(begin: 12, end: 0);
                    }),
                    const SizedBox(height: 16),
                  ],

                  // ── Volunteer Duties ─────────────────────────────────────
                  _sectionHeader(
                      'Your Volunteer Duties', Icons.volunteer_activism_outlined),
                  const SizedBox(height: 8),
                  if (_volunteerDuties.isEmpty)
                    _emptyState('No duties scheduled this week')
                        .animate()
                        .fadeIn(duration: AppAnimations.cardFadeInDuration)
                  else
                    ..._volunteerDuties.asMap().entries.map((e) {
                      final i = e.key;
                      final duty = e.value;
                      return _DutyCard(duty: duty)
                          .animate()
                          .fadeIn(
                            duration: AppAnimations.cardFadeInDuration,
                            delay: Duration(
                                milliseconds:
                                    i * AppAnimations.staggerItemDelay.inMilliseconds),
                          );
                    }),

                  const SizedBox(height: 16),

                  // ── Class Schedule ───────────────────────────────────────
                  _sectionHeader('Class Schedule', Icons.class_outlined),
                  const SizedBox(height: 8),
                  if (_classSlots.isEmpty)
                    _emptyState('No classes found')
                        .animate()
                        .fadeIn(duration: AppAnimations.cardFadeInDuration)
                  else
                    ..._classSlots.asMap().entries.map((e) {
                      final i = e.key;
                      final cls = e.value;
                      return _ClassSlotCard(data: cls)
                          .animate()
                          .fadeIn(
                            duration: AppAnimations.cardFadeInDuration,
                            delay: Duration(
                                milliseconds:
                                    i * AppAnimations.staggerItemDelay.inMilliseconds),
                          );
                    }),

                  const SizedBox(height: 16),

                  // ── Next Week Preview ────────────────────────────────────
                  if (_nextWeekPreview != null) ...[
                    _sectionHeader(
                        'Coming Up Next Week', Icons.event_note_outlined),
                    const SizedBox(height: 8),
                    _SectionCard(
                      child: Row(
                        children: [
                          const Icon(Icons.arrow_forward_ios,
                              size: 16, color: AppTheme.navyLight),
                          const SizedBox(width: 8),
                          Text(
                            'Memory Work Unit ${_nextWeekPreview!['unit']}',
                            style: const TextStyle(
                                color: AppTheme.navyDark,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: AppAnimations.cardFadeInDuration),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.navy),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.navyDark)),
          ],
        ),
      );

  Widget _emptyState(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(text,
            style: const TextStyle(color: AppTheme.textTertiary, fontSize: 13)),
      );
}

// ── Week Header ───────────────────────────────────────────────────────────────
class _WeekHeader extends StatelessWidget {
  final DateTime weekRef;
  final ValueChanged<DateTime> onWeekChanged;

  const _WeekHeader({required this.weekRef, required this.onWeekChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => onWeekChanged(WeekUtils.prevWeek(weekRef)),
        ),
        Column(
          children: [
            Text(
              WeekUtils.isCurrentWeek(weekRef) ? 'This Week' : 'Week',
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary),
            ),
            Text(
              WeekUtils.weekLabel(weekRef),
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.navyDark),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => onWeekChanged(WeekUtils.nextWeek(weekRef)),
        ),
      ],
    );
  }
}

// ── Child Progress Card ───────────────────────────────────────────────────────
class _ChildProgress {
  final String uid;
  final String name;
  final List<SubjectModel> subjects;
  final Set<String> practicedSubjectIds;

  _ChildProgress({
    required this.uid,
    required this.name,
    required this.subjects,
    required this.practicedSubjectIds,
  });
}

class _ChildProgressCard extends StatelessWidget {
  final _ChildProgress child;
  const _ChildProgressCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final total = child.subjects.length;
    final done = child.practicedSubjectIds.length;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline,
                  size: 16, color: AppTheme.navy),
              const SizedBox(width: 6),
              Text(child.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: AppTheme.navyDark)),
              const Spacer(),
              Text('$done / $total',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: AppTheme.navy)),
            ],
          ),
          const SizedBox(height: 10),
          // Progress dots
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: child.subjects.map((s) {
              final practiced = child.practicedSubjectIds.contains(s.id);
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: practiced
                      ? AppTheme.success
                      : AppTheme.surfaceVariant,
                  border: Border.all(
                    color: practiced
                        ? AppTheme.success
                        : AppTheme.cardBorder,
                  ),
                ),
                child: Icon(
                  practiced ? Icons.check : Icons.circle_outlined,
                  size: 14,
                  color: practiced ? Colors.white : AppTheme.textTertiary,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Duty Card ─────────────────────────────────────────────────────────────────
class _DutyCard extends StatelessWidget {
  final Map<String, dynamic> duty;
  const _DutyCard({required this.duty});

  @override
  Widget build(BuildContext context) {
    final dt = duty['date'] as DateTime;
    final partners = (duty['partners'] as List).cast<String>();

    return _SectionCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.calendarColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.volunteer_activism,
                color: AppTheme.calendarColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(DateFormat('EEEE, MMM d').format(dt),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: AppTheme.navyDark)),
                Text(duty['type'] as String? ?? 'Duty',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13)),
                if (partners.isNotEmpty)
                  Text('With: ${partners.join(', ')}',
                      style: const TextStyle(
                          color: AppTheme.textTertiary,
                          fontSize: 12,
                          fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Class Slot Card ───────────────────────────────────────────────────────────
class _ClassSlotCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ClassSlotCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Row(
        children: [
          const Icon(Icons.class_outlined, color: AppTheme.classesColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['name'] as String? ?? 'Class',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, color: AppTheme.navyDark)),
                if ((data['schedule'] as String?)?.isNotEmpty == true)
                  Text(data['schedule'] as String,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable Section Card ─────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
