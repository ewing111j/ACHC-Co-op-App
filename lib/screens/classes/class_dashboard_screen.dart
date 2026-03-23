// lib/screens/classes/class_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../models/class_models.dart';
import '../../utils/app_theme.dart';
import 'homework_sheet.dart';
import 'class_announcements_screen.dart';
import 'ask_mentor_screen.dart';
import 'class_files_screen.dart';
import 'gradebook_screen.dart';
import 'add_class_sheet.dart';

class ClassDashboardScreen extends StatefulWidget {
  final ClassModel classModel;
  final UserModel user;
  const ClassDashboardScreen(
      {super.key, required this.classModel, required this.user});

  @override
  State<ClassDashboardScreen> createState() => _ClassDashboardScreenState();
}

class _ClassDashboardScreenState extends State<ClassDashboardScreen> {
  static const int _pageCenter = 5000;
  late final PageController _pageCtrl;
  final _db = FirebaseFirestore.instance;
  List<ClassWeekModel> _weeks = [];
  bool _weeksLoaded = false;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(initialPage: _pageCenter);
    _loadWeeks();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadWeeks() async {
    try {
      final snap = await _db
          .collection('classes')
          .doc(widget.classModel.id)
          .collection('weeks')
          .orderBy('weekStart')
          .get();
      final weeks = snap.docs
          .map((d) => ClassWeekModel.fromMap(d.data(), d.id, widget.classModel.id))
          .toList();
      if (mounted) setState(() { _weeks = weeks; _weeksLoaded = true; });
      // Jump to current week
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToCurrentWeek());
    } catch (e) {
      if (mounted) setState(() => _weeksLoaded = true);
    }
  }

  void _jumpToCurrentWeek() {
    if (_weeks.isEmpty) return;
    final now = DateTime.now();
    int idx = _weeks.indexWhere(
        (w) => !now.isBefore(w.weekStart) && !now.isAfter(w.weekEnd));
    if (idx < 0) {
      // Find closest upcoming week
      idx = _weeks.indexWhere((w) => w.weekStart.isAfter(now));
    }
    if (idx < 0) idx = _weeks.length - 1;
    // Map to page index
    final page = _pageCenter + idx - (_weeks.length ~/ 2);
    _pageCtrl.jumpToPage(page.clamp(0, 9999));
  }

  ClassWeekModel? _weekForPage(int page) {
    if (_weeks.isEmpty) return null;
    final idx = (page - _pageCenter + (_weeks.length ~/ 2))
        .clamp(0, _weeks.length - 1);
    return _weeks[idx];
  }

  Color get _classColor => Color(widget.classModel.colorValue);

  @override
  Widget build(BuildContext context) {
    final cls = widget.classModel;
    final user = widget.user;
    final color = _classColor;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(cls.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (user.canEditClasses)
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) =>
                    AddClassSheet(user: user, db: _db, editClass: cls),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.grade_outlined, size: 20),
            tooltip: 'Gradebook',
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => GradebookScreen(
                        classModel: cls, user: user))),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Class header ─────────────────────────────────────────
          _ClassHeader(cls: cls, user: user, db: _db, color: color),
          AppTheme.goldDivider(),
          // ── Quick action row ─────────────────────────────────────
          _QuickActions(cls: cls, user: user),
          const Divider(height: 1),
          // ── Week nav bar ─────────────────────────────────────────
          if (_weeksLoaded)
            _WeekNavBar(
              pageCtrl: _pageCtrl,
              pageCenter: _pageCenter,
              weeks: _weeks,
              weekForPage: _weekForPage,
              canEdit: user.canEditClasses,
              db: _db,
              classId: cls.id,
              onWeeksChanged: _loadWeeks,
            ),
          if (!_weeksLoaded)
            const LinearProgressIndicator(
                backgroundColor: AppTheme.surfaceVariant,
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppTheme.classesColor)),
          AppTheme.goldDivider(),
          // ── Week content ─────────────────────────────────────────
          Expanded(
            child: _weeksLoaded
                ? (_weeks.isEmpty
                    ? _NoWeeks(canEdit: user.canEditClasses)
                    : PageView.builder(
                        controller: _pageCtrl,
                        onPageChanged: (_) => setState(() {}),
                        itemBuilder: (ctx, page) {
                          final week = _weekForPage(page);
                          if (week == null) return const SizedBox.shrink();
                          return _WeekContent(
                            week: week,
                            classModel: cls,
                            user: user,
                            db: _db,
                            color: color,
                          );
                        },
                      ))
                : const Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
      floatingActionButton: user.canEditClasses
          ? FloatingActionButton(
              onPressed: () {
                final week = _weekForPage(
                    _pageCtrl.page?.round() ?? _pageCenter);
                if (week == null) return;
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => HomeworkSheet(
                    classModel: cls,
                    week: week,
                    user: user,
                    db: _db,
                  ),
                );
              },
              backgroundColor: color,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

// ── Class Header ──────────────────────────────────────────────────────────────
class _ClassHeader extends StatelessWidget {
  final ClassModel cls;
  final UserModel user;
  final FirebaseFirestore db;
  final Color color;
  const _ClassHeader(
      {required this.cls, required this.user, required this.db, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Text(cls.shortname,
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cls.name,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.people_outline,
                      size: 12, color: AppTheme.textHint),
                  const SizedBox(width: 3),
                  Text('${cls.enrolledUids.length} enrolled',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary)),
                  if (user.isStudent) ...[
                    const SizedBox(width: 10),
                    _MiniProgress(
                        classId: cls.id, studentUid: user.uid, db: db, color: color),
                  ],
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniProgress extends StatelessWidget {
  final String classId;
  final String studentUid;
  final FirebaseFirestore db;
  final Color color;
  const _MiniProgress({
    required this.classId,
    required this.studentUid,
    required this.db,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<double>(
      future: _calc(),
      builder: (ctx, snap) {
        final pct = snap.data ?? 0.0;
        final c = pct >= 0.95
            ? AppTheme.optionalGreen
            : pct >= 0.90
                ? AppTheme.warning
                : AppTheme.error;
        return Row(children: [
          SizedBox(
            width: 60,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                  value: pct,
                  backgroundColor: AppTheme.cardBorder,
                  valueColor: AlwaysStoppedAnimation<Color>(c),
                  minHeight: 5),
            ),
          ),
          const SizedBox(width: 4),
          Text('${(pct * 100).round()}%',
              style: TextStyle(
                  fontSize: 10, color: c, fontWeight: FontWeight.w700)),
        ]);
      },
    );
  }

  Future<double> _calc() async {
    try {
      // Aggregate across all weeks in this class
      final weeksSnap = await db
          .collection('classes')
          .doc(classId)
          .collection('weeks')
          .where('isBreak', isEqualTo: false)
          .get();
      int totalHw = 0;
      int doneHw = 0;
      for (final weekDoc in weeksSnap.docs) {
        final hwSnap = await db
            .collection('classes')
            .doc(classId)
            .collection('weeks')
            .doc(weekDoc.id)
            .collection('homework')
            .where('isHidden', isEqualTo: false)
            .get();
        totalHw += hwSnap.docs.length;
        for (final hwDoc in hwSnap.docs) {
          final subSnap = await db
              .collection('classes')
              .doc(classId)
              .collection('weeks')
              .doc(weekDoc.id)
              .collection('homework')
              .doc(hwDoc.id)
              .collection('submissions')
              .where('studentUid', isEqualTo: studentUid)
              .where('status', whereIn: ['complete', 'submitted', 'graded'])
              .limit(1)
              .get();
          if (subSnap.docs.isNotEmpty) doneHw++;
        }
      }
      if (totalHw == 0) return 1.0;
      return doneHw / totalHw;
    } catch (_) {
      return 0.0;
    }
  }
}

// ── Quick action buttons (Announce, Ask Mentor, Files) ────────────────────────
class _QuickActions extends StatelessWidget {
  final ClassModel cls;
  final UserModel user;
  const _QuickActions({required this.cls, required this.user});

  @override
  Widget build(BuildContext context) {
    final color = Color(cls.colorValue);
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _QBtn(
            icon: Icons.campaign_outlined,
            label: 'Announce',
            color: color,
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ClassAnnouncementsScreen(
                        classModel: cls, user: user))),
          ),
          _QBtn(
            icon: Icons.help_outline,
            label: 'Ask Mentor',
            color: color,
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => AskMentorScreen(
                        classModel: cls, user: user))),
          ),
          _QBtn(
            icon: Icons.folder_outlined,
            label: 'Files',
            color: color,
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ClassFilesScreen(
                        classModel: cls, user: user))),
          ),
          if (user.canEditClasses || user.isAdmin)
            _QBtn(
              icon: Icons.grade_outlined,
              label: 'Grades',
              color: color,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          GradebookScreen(classModel: cls, user: user))),
            ),
        ],
      ),
    );
  }
}

class _QBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Week Navigation Bar ───────────────────────────────────────────────────────
class _WeekNavBar extends StatefulWidget {
  final PageController pageCtrl;
  final int pageCenter;
  final List<ClassWeekModel> weeks;
  final ClassWeekModel? Function(int) weekForPage;
  final bool canEdit;
  final FirebaseFirestore db;
  final String classId;
  final VoidCallback onWeeksChanged;

  const _WeekNavBar({
    required this.pageCtrl,
    required this.pageCenter,
    required this.weeks,
    required this.weekForPage,
    required this.canEdit,
    required this.db,
    required this.classId,
    required this.onWeeksChanged,
  });

  @override
  State<_WeekNavBar> createState() => _WeekNavBarState();
}

class _WeekNavBarState extends State<_WeekNavBar> {
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.pageCtrl.initialPage;
    widget.pageCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    final p = widget.pageCtrl.page?.round() ?? _currentPage;
    if (p != _currentPage && mounted) setState(() => _currentPage = p);
  }

  @override
  void dispose() {
    widget.pageCtrl.removeListener(_onScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final week = widget.weekForPage(_currentPage);
    final label = week?.displayLabel ?? 'No weeks';
    final isBreak = week?.isBreak ?? false;

    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => widget.pageCtrl.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isBreak)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('BREAK WEEK',
                        style: TextStyle(
                            fontSize: 9,
                            color: AppTheme.warning,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1)),
                  ),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => widget.pageCtrl.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut),
          ),
        ],
      ),
    );
  }
}

// ── Week Content (homework list) ──────────────────────────────────────────────
class _WeekContent extends StatelessWidget {
  final ClassWeekModel week;
  final ClassModel classModel;
  final UserModel user;
  final FirebaseFirestore db;
  final Color color;

  const _WeekContent({
    required this.week,
    required this.classModel,
    required this.user,
    required this.db,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (week.isBreak && !user.canEditClasses) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.beach_access_outlined,
                size: 56, color: AppTheme.textHint),
            const SizedBox(height: 12),
            const Text('Break Week',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary)),
            const SizedBox(height: 4),
            Text(week.displayLabel,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textHint)),
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: db
          .collection('classes')
          .doc(classModel.id)
          .collection('weeks')
          .doc(week.id)
          .collection('homework')
          .snapshots(), // No orderBy — avoids requiring a Firestore index
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        // All roles see homework — mentors also see hidden items
        final homework = docs
            .map((d) => HomeworkModel.fromMap(d.data() as Map<String, dynamic>, d.id))
            .where((h) => user.canEditClasses || !h.isHidden)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)); // sort in memory

        // Overdue items (past weeks)
        final now = DateTime.now();
        final isCurrentWeek =
            !now.isBefore(week.weekStart) && !now.isAfter(week.weekEnd);
        final isPastWeek = now.isAfter(week.weekEnd);

        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            // Week notes
            if (week.notes.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Text(week.notes,
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textSecondary)),
              ),
            ],
            // Overdue banner
            if (isPastWeek && user.isStudent)
              _OverdueBanner(
                  weekId: week.id,
                  classId: classModel.id,
                  studentUid: user.uid,
                  db: db),
            if (homework.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 48,
                        color: isCurrentWeek
                            ? color.withValues(alpha: 0.4)
                            : AppTheme.textHint),
                    const SizedBox(height: 12),
                    Text(
                      week.isBreak
                          ? 'Break week — no homework assigned'
                          : user.canEditClasses
                              ? 'No homework added yet.\nTap + to add homework.'
                              : 'No homework this week',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
              )
            else
              ...homework.map((hw) => _HomeworkCard(
                    homework: hw,
                    classModel: classModel,
                    week: week,
                    user: user,
                    db: db,
                    color: color,
                  )),
          ],
        );
      },
    );
  }
}

// ── Overdue Banner ────────────────────────────────────────────────────────────
class _OverdueBanner extends StatelessWidget {
  final String weekId;
  final String classId;
  final String studentUid;
  final FirebaseFirestore db;
  const _OverdueBanner({
    required this.weekId,
    required this.classId,
    required this.studentUid,
    required this.db,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _countOverdue(),
      builder: (ctx, snap) {
        final count = snap.data ?? 0;
        if (count == 0) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 16, color: AppTheme.error),
              const SizedBox(width: 8),
              Text(
                '$count item${count == 1 ? '' : 's'} not submitted',
                style: const TextStyle(
                    color: AppTheme.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<int> _countOverdue() async {
    try {
      final hw = await db
          .collection('classes')
          .doc(classId)
          .collection('weeks')
          .doc(weekId)
          .collection('homework')
          .get();
      if (hw.docs.isEmpty) return 0;
      int overdue = 0;
      for (final doc in hw.docs) {
        final sub = await db
            .collection('classes')
            .doc(classId)
            .collection('weeks')
            .doc(weekId)
            .collection('homework')
            .doc(doc.id)
            .collection('submissions')
            .where('studentUid', isEqualTo: studentUid)
            .limit(1)
            .get();
        if (sub.docs.isEmpty) overdue++;
      }
      return overdue;
    } catch (_) {
      return 0;
    }
  }
}

// ── Homework Card ─────────────────────────────────────────────────────────────
class _HomeworkCard extends StatefulWidget {
  final HomeworkModel homework;
  final ClassModel classModel;
  final ClassWeekModel week;
  final UserModel user;
  final FirebaseFirestore db;
  final Color color;

  const _HomeworkCard({
    required this.homework,
    required this.classModel,
    required this.week,
    required this.user,
    required this.db,
    required this.color,
  });

  @override
  State<_HomeworkCard> createState() => _HomeworkCardState();
}

class _HomeworkCardState extends State<_HomeworkCard> {
  SubmissionModel? _submission;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSubmission();
  }

  Future<void> _loadSubmission() async {
    // Only load submission for non-editors (students / parents in a class)
    if (widget.user.canEditClasses) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final snap = await widget.db
          .collection('classes')
          .doc(widget.homework.classId)
          .collection('weeks')
          .doc(widget.homework.weekId)
          .collection('homework')
          .doc(widget.homework.id)
          .collection('submissions')
          .where('studentUid', isEqualTo: widget.user.uid)
          .limit(1)
          .get();
      if (mounted) {
        setState(() {
          _submission = snap.docs.isEmpty
              ? null
              : SubmissionModel.fromMap(
                  snap.docs.first.data(), snap.docs.first.id);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _isDone => _submission?.isComplete ?? false;

  @override
  Widget build(BuildContext context) {
    final hw = widget.homework;
    final color = widget.color;
    final isDone = _isDone;

    return GestureDetector(
      onTap: () async {
        // Non-editors (students / enrolled parents) see submission view;
        // mentors/admins see the edit form
        if (!widget.user.canEditClasses) {
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => HomeworkDetailSheet(
              hw: hw,
              classModel: widget.classModel,
              week: widget.week,
              user: widget.user,
              db: widget.db,
              existingSubmission: _submission,
            ),
          );
          _loadSubmission(); // refresh after returning
        } else {
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => HomeworkSheet(
              classModel: widget.classModel,
              week: widget.week,
              user: widget.user,
              db: widget.db,
              editHw: hw,
              existingSubmission: _submission,
              onSubmissionChanged: () {
                _loadSubmission();
              },
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDone
              ? AppTheme.surface.withValues(alpha: 0.7)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border(
            left: BorderSide(
                color: isDone ? AppTheme.optionalGreen : color, width: 4),
            top: const BorderSide(color: AppTheme.cardBorder),
            right: const BorderSide(color: AppTheme.cardBorder),
            bottom: const BorderSide(color: AppTheme.cardBorder),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Toggle circle
              if (!widget.user.canEditClasses)
                GestureDetector(
                  onTap: _loading ? null : _toggleComplete,
                  child: Container(
                    margin: const EdgeInsets.only(top: 2, right: 10),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: isDone ? AppTheme.optionalGreen : color,
                          width: 2),
                      color: isDone
                          ? AppTheme.optionalGreen.withValues(alpha: 0.15)
                          : Colors.transparent,
                    ),
                    child: isDone
                        ? const Icon(Icons.check,
                            size: 13, color: AppTheme.optionalGreen)
                        : null,
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            hw.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDone
                                  ? AppTheme.textHint
                                  : AppTheme.textPrimary,
                              decoration: isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        if (hw.isHidden)
                          const Icon(Icons.visibility_off_outlined,
                              size: 14, color: AppTheme.textHint),
                        // Item type badge (quiz/test)
                        if (hw.isQuiz || hw.isTest)
                          Container(
                            margin: const EdgeInsets.only(right: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: hw.isQuiz
                                  ? AppTheme.classesColor.withValues(alpha: 0.12)
                                  : AppTheme.mandatoryRed.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              hw.isQuiz ? 'Quiz' : 'Test',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: hw.isQuiz
                                    ? AppTheme.classesColor
                                    : AppTheme.mandatoryRed,
                              ),
                            ),
                          ),
                        // Grade badge
                        if (_submission?.grade != null)
                          _GradeBadge(
                              grade: _submission!.grade!,
                              classModel: widget.classModel),
                        if (widget.user.canEditClasses)
                          _HomeworkMenu(
                            homework: hw,
                            db: widget.db,
                            classModel: widget.classModel,
                            week: widget.week,
                            user: widget.user,
                          ),
                      ],
                    ),
                    if (hw.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(hw.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDone
                                ? AppTheme.textHint
                                : AppTheme.textSecondary,
                            decoration:
                                isDone ? TextDecoration.lineThrough : null,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                    if (hw.checklist.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      ...hw.checklist.take(3).map((item) {
                        final checked = _submission?.checklistDone[item] ?? false;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Row(children: [
                            Icon(
                              checked
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              size: 12,
                              color: checked
                                  ? AppTheme.optionalGreen
                                  : AppTheme.textHint,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                                child: Text(item,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: checked
                                            ? AppTheme.textHint
                                            : AppTheme.textSecondary,
                                        decoration: checked
                                            ? TextDecoration.lineThrough
                                            : null),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis)),
                          ]),
                        );
                      }),
                      if (hw.checklist.length > 3)
                        Text('+${hw.checklist.length - 3} more…',
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textHint)),
                    ],
                    if (hw.dueDate != null) ...[
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.schedule,
                            size: 12, color: AppTheme.textHint),
                        const SizedBox(width: 4),
                        Text(
                          'Due ${DateFormat('MMM d').format(hw.dueDate!)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: hw.dueDate!.isBefore(DateTime.now()) &&
                                    !isDone
                                ? AppTheme.error
                                : AppTheme.textHint,
                          ),
                        ),
                      ]),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleComplete() async {
    final hw = widget.homework;
    final wasComplete = _isDone;
    // Optimistic update
    setState(() {
      if (_submission == null) {
        _submission = SubmissionModel(
          id: '',
          homeworkId: hw.id,
          classId: widget.classModel.id,
          weekId: widget.week.id,
          studentUid: widget.user.uid,
          studentName: widget.user.displayName,
          status: 'complete',
          submittedAt: DateTime.now(),
        );
      } else {
        _submission = SubmissionModel(
          id: _submission!.id,
          homeworkId: hw.id,
          classId: widget.classModel.id,
          weekId: widget.week.id,
          studentUid: widget.user.uid,
          studentName: widget.user.displayName,
          status: wasComplete ? 'incomplete' : 'complete',
          grade: _submission!.grade,
          feedback: _submission!.feedback,
          submittedAt: DateTime.now(),
          checklistDone: _submission!.checklistDone,
        );
      }
    });
    try {
      // Nested path: classes/{id}/weeks/{weekId}/homework/{hwId}/submissions
      final subColRef = widget.db
          .collection('classes')
          .doc(widget.homework.classId)
          .collection('weeks')
          .doc(widget.homework.weekId)
          .collection('homework')
          .doc(widget.homework.id)
          .collection('submissions');

      if (_submission!.id.isEmpty) {
        // Create new submission
        final ref = subColRef.doc();
        await ref.set({
          ..._submission!.toMap(),
          'submittedAt': FieldValue.serverTimestamp(),
        });
        if (mounted) setState(() => _submission = SubmissionModel(
              id: ref.id,
              homeworkId: _submission!.homeworkId,
              classId: _submission!.classId,
              weekId: _submission!.weekId,
              studentUid: _submission!.studentUid,
              studentName: _submission!.studentName,
              status: _submission!.status,
              submittedAt: DateTime.now(),
            ));
      } else {
        await subColRef.doc(_submission!.id).update({
          'status': _submission!.status,
          'submittedAt': FieldValue.serverTimestamp(),
        });
      }
      // Undo snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(wasComplete ? 'Marked incomplete' : '✓ Marked complete'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: _toggleComplete,
          ),
        ));
      }
    } catch (e) {
      // Roll back
      await _loadSubmission();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.error));
      }
    }
  }
}

class _GradeBadge extends StatelessWidget {
  final double grade;
  final ClassModel classModel;
  const _GradeBadge({required this.grade, required this.classModel});

  @override
  Widget build(BuildContext context) {
    final color = grade >= 90
        ? AppTheme.optionalGreen
        : grade >= 70
            ? AppTheme.warning
            : AppTheme.error;
    final letter = classModel.gradebookSimple
        ? null
        : _letter(grade);
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        letter ?? '${grade.round()}%',
        style:
            TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

  String _letter(double g) {
    if (g >= classModel.gradeA) return 'A';
    if (g >= classModel.gradeB) return 'B';
    if (g >= classModel.gradeC) return 'C';
    if (g >= classModel.gradeD) return 'D';
    return 'F';
  }
}

class _HomeworkMenu extends StatelessWidget {
  final HomeworkModel homework;
  final FirebaseFirestore db;
  final ClassModel classModel;
  final ClassWeekModel week;
  final UserModel user;
  const _HomeworkMenu({
    required this.homework,
    required this.db,
    required this.classModel,
    required this.week,
    required this.user,
  });

  // Correct nested path: classes/{id}/weeks/{weekId}/homework/{hwId}
  DocumentReference get _hwRef => db
      .collection('classes')
      .doc(classModel.id)
      .collection('weeks')
      .doc(week.id)
      .collection('homework')
      .doc(homework.id);

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 16, color: AppTheme.textHint),
      onSelected: (v) async {
        if (v == 'edit') {
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => HomeworkSheet(
              classModel: classModel,
              week: week,
              user: user,
              db: db,
              editHw: homework,
            ),
          );
        } else if (v == 'hide') {
          await _hwRef.update({'isHidden': !homework.isHidden});
        } else if (v == 'delete') {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Delete Homework?'),
              content: Text('Delete "${homework.title}"? This cannot be undone.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.error,
                      foregroundColor: Colors.white),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
          if (confirmed == true) await _hwRef.delete();
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(children: [
            Icon(Icons.edit_outlined, size: 16),
            SizedBox(width: 8),
            Text('Edit'),
          ]),
        ),
        PopupMenuItem(
          value: 'hide',
          child: Row(children: [
            Icon(homework.isHidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 16),
            const SizedBox(width: 8),
            Text(homework.isHidden ? 'Show' : 'Hide'),
          ]),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            Icon(Icons.delete_outline, size: 16, color: AppTheme.error),
            SizedBox(width: 8),
            Text('Delete', style: TextStyle(color: AppTheme.error)),
          ]),
        ),
      ],
    );
  }
}

class _NoWeeks extends StatelessWidget {
  final bool canEdit;
  const _NoWeeks({required this.canEdit});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_today_outlined,
              size: 56, color: AppTheme.textHint),
          const SizedBox(height: 12),
          const Text('No weeks loaded yet',
              style:
                  TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          if (canEdit)
            const Text(
              'Weeks are auto-generated from the admin calendar.\nMake sure the Co-op Calendar has been set up.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textHint),
            ),
        ],
      ),
    );
  }
}
