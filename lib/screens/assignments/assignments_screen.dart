// lib/screens/assignments/assignments_screen.dart
// Overhaul: 2-tab layout (Weekly | Overview), series-aware editing,
// course-grouped ExpansionTiles, swipe week navigation, in-place completion.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:uuid/uuid.dart';
import '../../providers/auth_provider.dart';
import '../../providers/assignments_provider.dart';
import '../../models/assignment_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../services/moodle_service.dart';
import '../../utils/app_theme.dart';
import '../moodle/moodle_setup_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// UUID generator for series IDs
// ─────────────────────────────────────────────────────────────────────────────
const _uuid = Uuid();
String _generateSeriesId() => _uuid.v4();

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class AssignmentsScreen extends StatefulWidget {
  const AssignmentsScreen({super.key});
  @override
  State<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends State<AssignmentsScreen>
    with SingleTickerProviderStateMixin {
  final _firestoreService = FirestoreService();
  final _moodleService = MoodleService();
  final _db = FirebaseFirestore.instance;

  late TabController _tabController;
  bool _isSyncing = false;
  String? _selectedKidUid;
  UserModel? _selectedStudent;
  List<UserModel> _students = [];

  @override
  void initState() {
    super.initState();
    // Tab 0 = Weekly (default), Tab 1 = Overview
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    if (user.moodleUrl != null && user.moodleToken != null) {
      _moodleService.configure(user.moodleUrl!, user.moodleToken!);
    }
    if (user.isParent || user.isAdmin) await _loadStudents(user);

    // Initialize Hive cache + start live Firestore subscription via Provider.
    final assignmentsProvider = context.read<AssignmentsProvider>();
    await assignmentsProvider.initHive();
    final familyId = user.familyId ?? '';
    final viewUid = user.isStudent ? user.uid : null;
    await assignmentsProvider.load(familyId, viewUid);
  }

  Future<void> _loadStudents(UserModel user) async {
    if (user.kidUids.isEmpty) return;
    final docs = await Future.wait(
        user.kidUids.map((uid) => _db.collection('users').doc(uid).get()));
    final kids = docs
        .where((d) => d.exists)
        .map((d) => UserModel.fromMap(d.data()!, d.id))
        .toList();
    if (mounted) setState(() => _students = kids);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Moodle sync ──────────────────────────────────────────────────
  Future<void> _syncMoodle() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null || !_moodleService.isConfigured) {
      _showMoodleSetup();
      return;
    }
    setState(() => _isSyncing = true);
    try {
      final siteInfo = await _moodleService.getUserInfo();
      if (siteInfo == null) {
        _showSnack('Could not connect to Moodle. Check your settings.',
            isError: true);
        return;
      }
      final moodleUserId = '${siteInfo['userid'] ?? ''}';
      final assignments = await _moodleService.getAllAssignments(moodleUserId);
      final familyId = user.familyId ?? '';
      final updated = assignments
          .map((a) => AssignmentModel(
                id: a.id,
                title: a.title,
                description: a.description,
                courseName: a.courseName,
                courseId: a.courseId,
                dueDate: a.dueDate,
                status: a.status,
                fromMoodle: a.fromMoodle,
                familyId: familyId,
                isOptional: false,
                createdAt: a.createdAt,
              ))
          .toList();
      await _firestoreService.saveAssignments(updated);
      _showSnack('Synced ${updated.length} assignments from Moodle');
    } catch (e) {
      _showSnack('Sync failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _showMoodleSetup() {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const MoodleSetupScreen()));
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppTheme.error : AppTheme.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Print ────────────────────────────────────────────────────────
  Future<void> _printAssignments(BuildContext context, UserModel user) async {
    final studentName = _selectedStudent?.displayName ?? user.displayName;
    final familyId = user.familyId ?? '';
    final viewUid =
        user.isStudent ? user.uid : (_selectedKidUid ?? user.uid);
    List<AssignmentModel> assignments = [];
    try {
      final snap = await FirebaseFirestore.instance
          .collection('assignments')
          .where('familyId', isEqualTo: familyId)
          .get();
      assignments = snap.docs
          .map((d) => AssignmentModel.fromMap(d.data(), d.id))
          .where((a) =>
              a.assignedTo == viewUid ||
              a.assignedTo == null ||
              a.assignedTo!.isEmpty ||
              a.assignedTo == 'all')
          .toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    } catch (e) {
      _showSnack('Could not load assignments for print', isError: true);
      return;
    }
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      build: (pw.Context ctx) => [
        pw.Header(
            level: 0,
            child: pw.Text('Assignments – $studentName',
                style: pw.TextStyle(
                    fontSize: 18, fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(height: 8),
        pw.Text('Printed: ${DateFormat('MMMM d, y').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 16),
        if (assignments.isEmpty)
          pw.Text('No assignments found.',
              style: const pw.TextStyle(fontSize: 12))
        else
          ...assignments.map((a) {
            final done = a.isDone;
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 8),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(4)),
              child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(done ? '[✓]' : '[ ]',
                        style: pw.TextStyle(
                            fontSize: 13, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(width: 8),
                    pw.Expanded(
                        child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                          pw.Text(a.title,
                              style: pw.TextStyle(
                                  fontSize: 13,
                                  fontWeight: pw.FontWeight.bold)),
                          if (a.courseName.isNotEmpty)
                            pw.Text(a.courseName,
                                style: const pw.TextStyle(
                                    fontSize: 11,
                                    color: PdfColors.grey600)),
                          if (a.description.isNotEmpty)
                            pw.Text(a.description,
                                style:
                                    const pw.TextStyle(fontSize: 11)),
                          pw.Text(
                              'Due: ${DateFormat('MMM d, y').format(a.dueDate)}',
                              style: pw.TextStyle(
                                  fontSize: 11,
                                  color: done
                                      ? PdfColors.green700
                                      : PdfColors.red700)),
                        ])),
                  ]),
            );
          }),
      ],
    ));
    await Printing.layoutPdf(
        onLayout: (_) async => doc.save(),
        name: 'Assignments_$studentName.pdf');
  }

  // ── Build ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser!;
    final familyId = user.familyId ?? '';
    final viewUid =
        user.isStudent ? user.uid : (_selectedKidUid ?? user.uid);

    // Students only get Weekly tab
    final tabCount = user.isStudent ? 1 : 2;
    if (_tabController.length != tabCount) {
      _tabController.dispose();
      _tabController = TabController(length: tabCount, vsync: this);
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Assignments'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Print',
            onPressed: () => _printAssignments(context, user),
          ),
          if (user.isParent || user.isAdmin)
            IconButton(
              icon: _isSyncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.sync),
              tooltip: 'Sync Moodle',
              onPressed: _isSyncing ? null : _syncMoodle,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(
                icon: Icon(Icons.calendar_view_week_outlined, size: 18),
                text: 'Weekly'),
            if (!user.isStudent)
              const Tab(
                  icon: Icon(Icons.list_alt_outlined, size: 18),
                  text: 'Overview'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Student selector (parents/admins)
          if ((user.isParent || user.isAdmin) && _students.isNotEmpty)
            _buildStudentSelector(),
          Expanded(
            child: StreamBuilder<List<AssignmentModel>>(
              stream:
                  _firestoreService.streamAssignments(familyId, viewUid),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Error: ${snapshot.error}',
                          style:
                              const TextStyle(color: AppTheme.error)));
                }
                final all = snapshot.data ?? [];
                final kidNames = _buildKidNames();

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _WeeklyTab(
                      assignments: all,
                      user: user,
                      db: _db,
                      kidNames: kidNames,
                      moodleConfigured: _moodleService.isConfigured,
                      onMoodleSetup: _showMoodleSetup,
                    ),
                    if (!user.isStudent)
                      _OverviewTab(
                        assignments: all,
                        user: user,
                        db: _db,
                        kidNames: kidNames,
                        moodleConfigured: _moodleService.isConfigured,
                        onMoodleSetup: _showMoodleSetup,
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: (user.isParent || user.isAdmin)
          ? FloatingActionButton.extended(
              onPressed: () {
                final kidInfos = _students
                    .map((k) =>
                        _KidInfo(uid: k.uid, name: k.displayName))
                    .toList();
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _AddAssignmentSheet(
                    user: user,
                    familyId: familyId,
                    kids: kidInfos,
                    db: _db,
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Task'),
              backgroundColor: AppTheme.assignmentsColor,
            )
          : null,
    );
  }

  Widget _buildStudentSelector() {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _KidChip(
              label: 'My Tasks',
              isSelected: _selectedKidUid == null,
              onTap: () => setState(
                  () => _selectedKidUid = _selectedStudent = null),
            ),
            ..._students.map((s) => _KidChip(
                  label: s.displayName,
                  isSelected: _selectedKidUid == s.uid,
                  onTap: () => setState(() {
                    _selectedKidUid = s.uid;
                    _selectedStudent = s;
                  }),
                )),
          ],
        ),
      ),
    );
  }

  Map<String, String> _buildKidNames() {
    return {for (final k in _students) k.uid: k.displayName};
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WEEKLY TAB  — swipeable week, course-grouped ExpansionTiles
// ─────────────────────────────────────────────────────────────────────────────
class _WeeklyTab extends StatefulWidget {
  final List<AssignmentModel> assignments;
  final UserModel user;
  final FirebaseFirestore db;
  final Map<String, String> kidNames;
  final bool moodleConfigured;
  final VoidCallback onMoodleSetup;

  const _WeeklyTab({
    required this.assignments,
    required this.user,
    required this.db,
    required this.kidNames,
    required this.moodleConfigured,
    required this.onMoodleSetup,
  });

  @override
  State<_WeeklyTab> createState() => _WeeklyTabState();
}

class _WeeklyTabState extends State<_WeeklyTab> {
  // PageView controller — very large page count, start at center page
  static const int _pageCenter = 5000;
  late final PageController _pageCtrl;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(initialPage: _pageCenter);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  /// Week start (Monday) for a given page offset from center
  DateTime _weekStart(int page) {
    final offset = page - _pageCenter;
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    return monday.add(Duration(days: offset * 7));
  }

  List<AssignmentModel> _assignmentsForWeek(int page) {
    final start = _weekStart(page);
    final end = start.add(const Duration(days: 7));
    return widget.assignments
        .where((a) =>
            !a.dueDate.isBefore(start) && a.dueDate.isBefore(end))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Week navigation bar ──────────────────────────────────
        _WeekNavBar(
          pageCtrl: _pageCtrl,
          pageCenter: _pageCenter,
          weekStartFn: _weekStart,
          assignmentsFn: _assignmentsForWeek,
        ),
        AppTheme.goldDivider(),
        // ── Swipeable page content ───────────────────────────────
        Expanded(
          child: PageView.builder(
            controller: _pageCtrl,
            onPageChanged: (_) => setState(() {}),
            itemBuilder: (context, page) {
              final weekAssignments = _assignmentsForWeek(page);
              if (weekAssignments.isEmpty) {
                return _EmptyWeek(
                  label: _weekLabel(_weekStart(page)),
                  moodleConfigured: widget.moodleConfigured,
                  isStudent: widget.user.isStudent,
                  onMoodleSetup: widget.onMoodleSetup,
                );
              }
              return _CourseGroupedList(
                assignments: weekAssignments,
                user: widget.user,
                db: widget.db,
                kidNames: widget.kidNames,
                initiallyExpanded: false, // collapsed by default
              );
            },
          ),
        ),
      ],
    );
  }

  String _weekLabel(DateTime start) {
    final end = start.add(const Duration(days: 6));
    final fmt = DateFormat('MMM d');
    return '${fmt.format(start)} – ${fmt.format(end)}, ${start.year}';
  }
}

// ── Week nav bar (extracted to rebuild only when page changes) ─────
class _WeekNavBar extends StatefulWidget {
  final PageController pageCtrl;
  final int pageCenter;
  final DateTime Function(int) weekStartFn;
  final List<AssignmentModel> Function(int) assignmentsFn;

  const _WeekNavBar({
    required this.pageCtrl,
    required this.pageCenter,
    required this.weekStartFn,
    required this.assignmentsFn,
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
    if (p != _currentPage) setState(() => _currentPage = p);
  }

  @override
  void dispose() {
    widget.pageCtrl.removeListener(_onScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final start = widget.weekStartFn(_currentPage);
    final end = start.add(const Duration(days: 6));
    final weekAssignments = widget.assignmentsFn(_currentPage);
    final pending =
        weekAssignments.where((a) => !a.isDone && !a.isOverdue).length;
    final done = weekAssignments.where((a) => a.isDone).length;
    final overdue = weekAssignments.where((a) => a.isOverdue).length;
    final isCurrentWeek = _currentPage == widget.pageCenter;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: AppTheme.surface,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => widget.pageCtrl.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut),
          ),
          Expanded(
            child: GestureDetector(
              onTap: isCurrentWeek
                  ? null
                  : () => widget.pageCtrl.animateToPage(
                        widget.pageCenter,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                      ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${DateFormat('MMM d').format(start)} – ${DateFormat('MMM d').format(end)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppTheme.textPrimary),
                      ),
                      if (!isCurrentWeek) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.navy.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Today',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: AppTheme.navy,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (pending > 0)
                        _StatChip('$pending pending',
                            AppTheme.mandatoryRed),
                      if (done > 0) ...[
                        if (pending > 0) const SizedBox(width: 6),
                        _StatChip('$done done', AppTheme.optionalGreen),
                      ],
                      if (overdue > 0) ...[
                        if (pending > 0 || done > 0)
                          const SizedBox(width: 6),
                        _StatChip('$overdue overdue', AppTheme.error),
                      ],
                      if (weekAssignments.isEmpty)
                        const Text('No tasks',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textHint)),
                    ],
                  ),
                ],
              ),
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

class _StatChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OVERVIEW TAB  — flat list, search, filter chips
// ─────────────────────────────────────────────────────────────────────────────
class _OverviewTab extends StatefulWidget {
  final List<AssignmentModel> assignments;
  final UserModel user;
  final FirebaseFirestore db;
  final Map<String, String> kidNames;
  final bool moodleConfigured;
  final VoidCallback onMoodleSetup;

  const _OverviewTab({
    required this.assignments,
    required this.user,
    required this.db,
    required this.kidNames,
    required this.moodleConfigured,
    required this.onMoodleSetup,
  });

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _filter = 'all'; // all | pending | done

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AssignmentModel> get _filtered {
    var list = widget.assignments;
    if (_filter == 'pending') {
      list = list
          .where((a) => !a.isDone)
          .toList();
    } else if (_filter == 'done') {
      list = list.where((a) => a.isDone).toList();
    }
    if (_query.isNotEmpty) {
      list = list
          .where((a) =>
              a.title.toLowerCase().contains(_query) ||
              a.courseName.toLowerCase().contains(_query) ||
              a.description.toLowerCase().contains(_query))
          .toList();
    }
    list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    return Column(
      children: [
        // Search + filter row
        Container(
          color: AppTheme.surface,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Column(
            children: [
              TextField(
                controller: _searchCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search assignments…',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () => _searchCtrl.clear())
                      : null,
                  isDense: true,
                  filled: true,
                  fillColor: AppTheme.surfaceVariant,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _FilterChip('All', 'all', _filter,
                      (v) => setState(() => _filter = v)),
                  const SizedBox(width: 8),
                  _FilterChip('Pending', 'pending', _filter,
                      (v) => setState(() => _filter = v)),
                  const SizedBox(width: 8),
                  _FilterChip('Done', 'done', _filter,
                      (v) => setState(() => _filter = v)),
                ],
              ),
            ],
          ),
        ),
        AppTheme.goldDivider(),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.assignment_outlined,
                          size: 56, color: AppTheme.textHint),
                      const SizedBox(height: 12),
                      Text(
                        _query.isNotEmpty
                            ? 'No matches for "$_query"'
                            : _filter == 'pending'
                                ? 'No pending assignments 🎉'
                                : _filter == 'done'
                                    ? 'No completed assignments yet'
                                    : 'No assignments found',
                        style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 15),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: items.length,
                  itemBuilder: (ctx, i) => _AssignmentCard(
                    assignment: items[i],
                    user: widget.user,
                    db: widget.db,
                    kidNames: widget.kidNames,
                  ),
                ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String current;
  final void Function(String) onTap;
  const _FilterChip(this.label, this.value, this.current, this.onTap);

  @override
  Widget build(BuildContext context) {
    final selected = value == current;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.assignmentsColor
              : AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected
                  ? AppTheme.assignmentsColor
                  : AppTheme.cardBorder),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.white
                    : AppTheme.textSecondary)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Course-grouped list (used by Weekly tab)
// ─────────────────────────────────────────────────────────────────────────────
class _CourseGroupedList extends StatelessWidget {
  final List<AssignmentModel> assignments;
  final UserModel user;
  final FirebaseFirestore db;
  final Map<String, String> kidNames;
  final bool initiallyExpanded;

  const _CourseGroupedList({
    required this.assignments,
    required this.user,
    required this.db,
    required this.kidNames,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    // Group by course (case-insensitive key, display original casing)
    final Map<String, List<AssignmentModel>> byCourse = {};
    final Map<String, String> displayKey = {}; // lower → display
    for (final a in assignments) {
      final key = a.courseName.trim().isEmpty
          ? 'General'
          : a.courseName.trim();
      final lower = key.toLowerCase();
      byCourse.putIfAbsent(lower, () => []).add(a);
      displayKey[lower] ??= key;
    }
    // Sort courses alphabetically
    final keys = byCourse.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.all(14),
      children: keys.map((lower) {
        final courseAssignments = byCourse[lower]!
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
        final courseName = displayKey[lower]!;
        final pendingCount = courseAssignments
            .where((a) => !a.isDone && !a.isOverdue)
            .length;
        final doneCount =
            courseAssignments.where((a) => a.isDone).length;
        final overdueCount =
            courseAssignments.where((a) => a.isOverdue).length;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Theme(
            data: Theme.of(context)
                .copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: initiallyExpanded,
              tilePadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 4),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(courseName,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 4),
                  Row(children: [
                    if (pendingCount > 0)
                      _StatChip('$pendingCount pending',
                          AppTheme.mandatoryRed),
                    if (doneCount > 0) ...[
                      if (pendingCount > 0) const SizedBox(width: 6),
                      _StatChip(
                          '$doneCount done', AppTheme.optionalGreen),
                    ],
                    if (overdueCount > 0) ...[
                      if (pendingCount > 0 || doneCount > 0)
                        const SizedBox(width: 6),
                      _StatChip(
                          '$overdueCount overdue', AppTheme.error),
                    ],
                  ]),
                ],
              ),
              children: courseAssignments
                  .map((a) => _AssignmentCard(
                        assignment: a,
                        user: user,
                        db: db,
                        kidNames: kidNames,
                        hideCourse: true,
                      ))
                  .toList(),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state for a week
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyWeek extends StatelessWidget {
  final String label;
  final bool moodleConfigured;
  final bool isStudent;
  final VoidCallback onMoodleSetup;

  const _EmptyWeek({
    required this.label,
    required this.moodleConfigured,
    required this.isStudent,
    required this.onMoodleSetup,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.event_available_outlined,
              size: 56, color: AppTheme.textHint),
          const SizedBox(height: 12),
          const Text('No tasks this week',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 15)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textHint, fontSize: 12)),
          if (!moodleConfigured && !isStudent) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onMoodleSetup,
              icon: const Icon(Icons.link),
              label: const Text('Connect Moodle'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.assignmentsColor),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Assignment Card  — in-place completion, collapsible description, edit menu
// ─────────────────────────────────────────────────────────────────────────────
class _AssignmentCard extends StatefulWidget {
  final AssignmentModel assignment;
  final UserModel user;
  final FirebaseFirestore db;
  final Map<String, String> kidNames;
  final bool hideCourse;

  const _AssignmentCard({
    required this.assignment,
    required this.user,
    required this.db,
    this.kidNames = const {},
    this.hideCourse = false,
  });

  @override
  State<_AssignmentCard> createState() => _AssignmentCardState();
}

class _AssignmentCardState extends State<_AssignmentCard> {
  bool _descExpanded = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.assignment;
    final isDone = a.isDone;
    final isOverdue = a.isOverdue;
    final isMandatory = !a.isOptional;

    final leftColor = isOverdue
        ? AppTheme.error
        : isMandatory
            ? AppTheme.mandatoryRed
            : AppTheme.optionalGreen;

    String? assignedName;
    if (a.assignedTo != null &&
        a.assignedTo != 'all' &&
        a.assignedTo!.isNotEmpty) {
      assignedName =
          widget.kidNames[a.assignedTo] ?? a.assignedTo;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10, left: 4, right: 4),
      decoration: BoxDecoration(
        color: isDone
            ? AppTheme.surface.withValues(alpha: 0.7)
            : AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: leftColor, width: 4),
          top: BorderSide(color: AppTheme.cardBorder),
          right: BorderSide(color: AppTheme.cardBorder),
          bottom: BorderSide(color: AppTheme.cardBorder),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Checkbox ──────────────────────────────────────────
            GestureDetector(
              onTap: () => _toggleStatus(),
              child: Container(
                margin: const EdgeInsets.only(top: 2),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: leftColor, width: 2),
                  color: isDone
                      ? leftColor.withValues(alpha: 0.15)
                      : Colors.transparent,
                ),
                child: isDone
                    ? Icon(Icons.check, size: 14, color: leftColor)
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            // ── Content ───────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          a.title,
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
                      if (a.fromMoodle)
                        const _MoodleTag(),
                      if (!a.fromMoodle &&
                          (widget.user.isAdmin ||
                              widget.user.isParent))
                        _EditMenu(
                          assignment: a,
                          user: widget.user,
                          db: widget.db,
                          kidNames: widget.kidNames,
                        ),
                    ],
                  ),
                  // Course name (optional)
                  if (!widget.hideCourse &&
                      a.courseName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(a.courseName,
                        style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11)),
                  ],
                  // Assigned-to
                  if (assignedName != null) ...[
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.person_outlined,
                          size: 11, color: AppTheme.navy),
                      const SizedBox(width: 3),
                      Text(assignedName,
                          style: const TextStyle(
                              color: AppTheme.navy,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ],
                  // Collapsible description
                  if (a.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => setState(
                          () => _descExpanded = !_descExpanded),
                      child: Text(
                        a.description,
                        style: TextStyle(
                          color: isDone
                              ? AppTheme.textHint
                              : AppTheme.textSecondary,
                          fontSize: 12,
                          decoration: isDone
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                        maxLines: _descExpanded ? null : 2,
                        overflow: _descExpanded
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                      ),
                    ),
                    if (!_descExpanded &&
                        a.description.length > 80)
                      GestureDetector(
                        onTap: () =>
                            setState(() => _descExpanded = true),
                        child: const Text('more…',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.navy,
                                fontWeight: FontWeight.w600)),
                      ),
                  ],
                  // Due date + mandatory badge
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.schedule,
                        size: 12,
                        color: isOverdue
                            ? AppTheme.error
                            : AppTheme.textHint),
                    const SizedBox(width: 4),
                    Text(
                      'Due ${DateFormat('MMM d').format(a.dueDate)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isOverdue
                            ? AppTheme.error
                            : AppTheme.textHint,
                        fontWeight: isOverdue
                            ? FontWeight.w700
                            : FontWeight.normal,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: leftColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isMandatory ? '● Required' : '○ Optional',
                        style: TextStyle(
                            fontSize: 10,
                            color: leftColor,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleStatus() {
    final a = widget.assignment;
    // Use Provider for optimistic update + Firestore write.
    try {
      context.read<AssignmentsProvider>().toggleStatus(a.id, a.status);
    } catch (_) {
      // Fallback: direct Firestore write if provider unavailable.
      final newStatus =
          (a.status == AssignmentStatus.pending ||
                  a.status == AssignmentStatus.overdue)
              ? AssignmentStatus.submitted
              : AssignmentStatus.pending;
      widget.db
          .collection('assignments')
          .doc(a.id)
          .update({'status': newStatus.name});
    }
  }
}

class _MoodleTag extends StatelessWidget {
  const _MoodleTag();
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: AppTheme.info.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4)),
      child: const Text('Moodle',
          style: TextStyle(color: AppTheme.info, fontSize: 10)),
    );
  }
}

// ── Edit / Delete popup menu ──────────────────────────────────────
class _EditMenu extends StatelessWidget {
  final AssignmentModel assignment;
  final UserModel user;
  final FirebaseFirestore db;
  final Map<String, String> kidNames;

  const _EditMenu({
    required this.assignment,
    required this.user,
    required this.db,
    required this.kidNames,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert,
          size: 16, color: AppTheme.textHint),
      onSelected: (v) {
        if (v == 'edit') _openEdit(context);
        if (v == 'delete') _confirmDelete(context);
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
            value: 'edit',
            child: Row(children: [
              Icon(Icons.edit_outlined, size: 16),
              SizedBox(width: 8),
              Text('Edit'),
            ])),
        const PopupMenuItem(
            value: 'delete',
            child: Row(children: [
              Icon(Icons.delete_outline,
                  size: 16, color: AppTheme.error),
              SizedBox(width: 8),
              Text('Delete',
                  style: TextStyle(color: AppTheme.error)),
            ])),
      ],
    );
  }

  void _openEdit(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddAssignmentSheet(
        user: user,
        familyId: assignment.familyId,
        kids: kidNames.entries
            .map((e) => _KidInfo(uid: e.key, name: e.value))
            .toList(),
        db: db,
        editAssignment: assignment,
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Assignment'),
        content: Text('Delete "${assignment.title}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await db
                  .collection('assignments')
                  .doc(assignment.id)
                  .delete();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper classes
// ─────────────────────────────────────────────────────────────────────────────
class _KidInfo {
  final String uid;
  final String name;
  const _KidInfo({required this.uid, required this.name});
}

class _KidChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _KidChip(
      {required this.label,
      required this.isSelected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.navy
              : AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected
                  ? AppTheme.navy
                  : AppTheme.cardBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD / EDIT Assignment Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _AddAssignmentSheet extends StatefulWidget {
  final UserModel user;
  final String familyId;
  final List<_KidInfo> kids;
  final FirebaseFirestore db;
  final AssignmentModel? editAssignment;

  const _AddAssignmentSheet({
    required this.user,
    required this.familyId,
    required this.kids,
    required this.db,
    this.editAssignment,
  });

  @override
  State<_AddAssignmentSheet> createState() =>
      _AddAssignmentSheetState();
}

class _AddAssignmentSheetState
    extends State<_AddAssignmentSheet> {
  final _titleCtrl = TextEditingController();
  final _courseCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _repeatUntilCtrl = TextEditingController();

  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  bool _isOptional = false;
  String _assignTo = 'all';
  bool _saving = false;

  // Repeat (add mode only)
  String _repeatMode = 'none';
  final Map<int, bool> _repeatDays = {
    1: false,
    2: false,
    3: false,
    4: false,
    5: false,
    6: false,
  };
  DateTime? _repeatUntilDate;

  // Edit mode: apply-to-series toggle
  bool _applyToSeries = false;

  bool get _isEdit => widget.editAssignment != null;

  DateTime get _defaultRepeatUntil {
    final now = DateTime.now();
    final june1 = DateTime(now.year, 6, 1);
    return june1.isAfter(now) ? june1 : DateTime(now.year + 1, 6, 1);
  }

  DateTime get _effectiveUntil =>
      _repeatUntilDate ?? _defaultRepeatUntil;

  static const _dayLabels = {
    1: 'Mon',
    2: 'Tue',
    3: 'Wed',
    4: 'Thu',
    5: 'Fri',
    6: 'Sat',
  };

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final a = widget.editAssignment!;
      _titleCtrl.text = a.title;
      _courseCtrl.text = a.courseName;
      _descCtrl.text = a.description;
      _dueDate = a.dueDate;
      _isOptional = a.isOptional;
      _assignTo = a.assignedTo ?? 'all';
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _courseCtrl.dispose();
    _descCtrl.dispose();
    _repeatUntilCtrl.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isSeriesEdit =
        _isEdit && widget.editAssignment!.isPartOfSeries;

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(children: [
                Text(
                    _isEdit
                        ? 'Edit Assignment'
                        : 'Add Assignment',
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ]),
              const SizedBox(height: 12),

              // Title
              TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Title *',
                      border: OutlineInputBorder())),
              const SizedBox(height: 10),

              // Course
              TextField(
                  controller: _courseCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Course / Subject',
                      border: OutlineInputBorder())),
              const SizedBox(height: 10),

              // Description
              TextField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                    labelText: 'Description',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder()),
                maxLines: 3,
                minLines: 2,
              ),
              const SizedBox(height: 10),

              // Due date
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                    'Due: ${DateFormat('MMM d, y').format(_dueDate)}',
                    style: const TextStyle(fontSize: 14)),
                trailing: const Icon(Icons.calendar_today,
                    size: 18, color: AppTheme.navy),
                onTap: () async {
                  final p = await showDatePicker(
                    context: context,
                    initialDate: _dueDate,
                    firstDate: DateTime.now()
                        .subtract(const Duration(days: 1)),
                    lastDate: DateTime.now()
                        .add(const Duration(days: 730)),
                  );
                  if (p != null) setState(() => _dueDate = p);
                },
              ),

              // Mandatory / optional
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Row(children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                        color: _isOptional
                            ? AppTheme.optionalGreen
                            : AppTheme.mandatoryRed,
                        shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                      _isOptional
                          ? 'Optional (green)'
                          : 'Mandatory (red)',
                      style: const TextStyle(fontSize: 14)),
                ]),
                value: _isOptional,
                activeThumbColor: AppTheme.optionalGreen,
                onChanged: (v) =>
                    setState(() => _isOptional = v),
              ),

              // Assign to
              if (widget.kids.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: _assignTo,
                  decoration: const InputDecoration(
                      labelText: 'Assign To',
                      border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem(
                        value: 'all',
                        child: Text('All Students')),
                    ...widget.kids.map((k) => DropdownMenuItem(
                        value: k.uid, child: Text(k.name))),
                  ],
                  onChanged: (v) =>
                      setState(() => _assignTo = v ?? 'all'),
                ),
              const SizedBox(height: 12),

              // ── Repeat section (add mode only) ──────────────────
              if (!_isEdit) ...[
                const Divider(),
                const SizedBox(height: 4),
                Row(children: [
                  const Text('Repeat',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  const Spacer(),
                  DropdownButton<String>(
                    value: _repeatMode,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(
                          value: 'none',
                          child: Text('No Repeat')),
                      DropdownMenuItem(
                          value: 'daily',
                          child: Text('Daily (M–F)')),
                      DropdownMenuItem(
                          value: 'weekly',
                          child: Text('Weekly')),
                      DropdownMenuItem(
                          value: 'custom',
                          child: Text('Custom Days')),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _repeatMode = v ?? 'none';
                        if (v == 'daily') {
                          for (int d = 1; d <= 5; d++) {
                            _repeatDays[d] = true;
                          }
                          _repeatDays[6] = false;
                        } else if (v != 'custom') {
                          for (final k in _repeatDays.keys) {
                            _repeatDays[k] = false;
                          }
                        }
                      });
                    },
                  ),
                ]),

                if (_repeatMode == 'custom') ...[
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                        border:
                            Border.all(color: AppTheme.cardBorder),
                        borderRadius:
                            BorderRadius.circular(10)),
                    child: Column(
                      children: _repeatDays.keys.map((day) {
                        return CheckboxListTile(
                          dense: true,
                          title: Text(_dayLabels[day]!,
                              style: const TextStyle(
                                  fontSize: 14)),
                          value: _repeatDays[day]!,
                          activeColor:
                              AppTheme.assignmentsColor,
                          onChanged: (v) => setState(
                              () => _repeatDays[day] =
                                  v ?? false),
                        );
                      }).toList(),
                    ),
                  ),
                  if (_repeatDays.values.every((v) => !v))
                    const Padding(
                      padding:
                          EdgeInsets.only(top: 4, left: 4),
                      child: Text('Select at least one day',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.error)),
                    ),
                ],

                if (_repeatMode != 'none') ...[
                  const SizedBox(height: 14),
                  const Text('Repeat Until',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _repeatUntilCtrl,
                        keyboardType: TextInputType.datetime,
                        decoration: InputDecoration(
                          hintText:
                              'MM/DD/YYYY  (default: ${DateFormat('MM/dd/yyyy').format(_defaultRepeatUntil)})',
                          hintStyle: const TextStyle(
                              fontSize: 12),
                          border:
                              const OutlineInputBorder(),
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10),
                        ),
                        onChanged: (_) =>
                            _parseUntilFromTextField(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(
                          Icons.calendar_month_outlined,
                          color: AppTheme.navy),
                      tooltip: 'Pick end date',
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _effectiveUntil,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now()
                              .add(const Duration(
                                  days: 730)),
                        );
                        if (picked != null) {
                          setState(() {
                            _repeatUntilDate = picked;
                            _repeatUntilCtrl.text =
                                DateFormat('MM/dd/yyyy')
                                    .format(picked);
                          });
                        }
                      },
                    ),
                  ]),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Generates instances up to ${DateFormat('MMM d, y').format(_effectiveUntil)}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textHint),
                    ),
                  ),
                ],
              ],

              // ── Apply-to-series toggle (edit mode, series only) ──
              if (_isEdit && isSeriesEdit) ...[
                const SizedBox(height: 12),
                const Divider(),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Apply to all future instances',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  subtitle: const Text(
                      'Updates this and all future assignments in the series',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary)),
                  value: _applyToSeries,
                  activeColor: AppTheme.assignmentsColor,
                  onChanged: (v) =>
                      setState(() => _applyToSeries = v ?? false),
                ),
              ],

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.assignmentsColor,
                      padding: const EdgeInsets.symmetric(
                          vertical: 14)),
                  child: _saving
                      ? const CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2)
                      : Text(_isEdit
                          ? 'Save Changes'
                          : 'Add Assignment'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _parseUntilFromTextField() {
    final text = _repeatUntilCtrl.text.trim();
    if (text.isEmpty) {
      setState(() => _repeatUntilDate = null);
      return;
    }
    try {
      setState(() =>
          _repeatUntilDate = DateFormat('MM/dd/yyyy').parseStrict(text));
    } catch (_) {}
  }

  // ── Save ─────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      _snack('Please enter a title', isError: true);
      return;
    }
    if (!_isEdit &&
        _repeatMode == 'custom' &&
        _repeatDays.values.every((v) => !v)) {
      _snack('Select at least one day for Custom Days',
          isError: true);
      return;
    }
    if (!_isEdit &&
        _repeatMode != 'none' &&
        _repeatUntilCtrl.text.isNotEmpty) {
      try {
        DateFormat('MM/dd/yyyy')
            .parseStrict(_repeatUntilCtrl.text.trim());
      } catch (_) {
        _snack(
            'Invalid date. Use MM/DD/YYYY (e.g. 06/01/2025)',
            isError: true);
        return;
      }
    }

    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await _saveEdit();
      } else {
        await _saveNew();
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveEdit() async {
    final a = widget.editAssignment!;
    final updates = {
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'courseName': _courseCtrl.text.trim().isEmpty
          ? 'General'
          : _courseCtrl.text.trim(),
      'dueDate': Timestamp.fromDate(_dueDate),
      'isOptional': _isOptional,
      'assignedTo': _assignTo,
    };

    if (_applyToSeries && a.isPartOfSeries) {
      // Query all future instances in the series
      final snap = await widget.db
          .collection('assignments')
          .where('seriesId', isEqualTo: a.seriesId)
          .where('dueDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(a.dueDate))
          .get();

      if (!mounted) return;

      // Confirmation dialog
      final count = snap.docs.length;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Update Series'),
          content: Text(
              'Update $count instance${count == 1 ? '' : 's'} '
              '(this and all future dates in the series)?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.assignmentsColor),
              child: const Text('Update All'),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        setState(() => _saving = false);
        return;
      }

      // Batch update all future instances
      const batchLimit = 400;
      final docs = snap.docs;
      for (int i = 0; i < docs.length; i += batchLimit) {
        final batch = widget.db.batch();
        for (final doc in docs.sublist(
            i,
            (i + batchLimit) < docs.length
                ? (i + batchLimit)
                : docs.length)) {
          batch.update(doc.reference, updates);
        }
        await batch.commit();
      }
    } else {
      // Single instance update
      await widget.db
          .collection('assignments')
          .doc(a.id)
          .update(updates);
    }
  }

  Future<void> _saveNew() async {
    final dates = _buildDates();
    if (dates.isEmpty) {
      _snack('No dates generated — check repeat settings',
          isError: true);
      setState(() => _saving = false);
      return;
    }

    // Generate a series ID for all repeating instances
    final seriesId =
        _repeatMode != 'none' ? _generateSeriesId() : null;

    const batchLimit = 400;
    for (int i = 0; i < dates.length; i += batchLimit) {
      final chunk = dates.sublist(
          i,
          (i + batchLimit) < dates.length
              ? (i + batchLimit)
              : dates.length);
      final batch = widget.db.batch();
      for (final date in chunk) {
        final ref = widget.db.collection('assignments').doc();
        batch.set(ref, {
          'title': _titleCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'courseName': _courseCtrl.text.trim().isEmpty
              ? 'General'
              : _courseCtrl.text.trim(),
          'courseId': 'manual',
          'dueDate': Timestamp.fromDate(date),
          'status': 'pending',
          'isOptional': _isOptional,
          'fromMoodle': false,
          'assignedTo': _assignTo,
          'familyId': widget.familyId,
          'createdAt': FieldValue.serverTimestamp(),
          if (seriesId != null) 'seriesId': seriesId,
          if (_repeatMode != 'none')
            'repeatUntil': Timestamp.fromDate(_effectiveUntil),
        });
      }
      await batch.commit();
    }
  }

  List<DateTime> _buildDates() {
    if (_repeatMode == 'none') return [_dueDate];
    final until = _effectiveUntil;
    final dates = <DateTime>[];

    if (_repeatMode == 'weekly') {
      var cur = _dueDate;
      while (!cur.isAfter(until)) {
        dates.add(cur);
        cur = cur.add(const Duration(days: 7));
      }
    } else {
      final active = _repeatMode == 'daily'
          ? [1, 2, 3, 4, 5]
          : _repeatDays.entries
              .where((e) => e.value)
              .map((e) => e.key)
              .toList();
      if (active.isEmpty) return [_dueDate];
      var cur = _dueDate;
      while (!cur.isAfter(until)) {
        if (active.contains(cur.weekday)) dates.add(cur);
        cur = cur.add(const Duration(days: 1));
      }
    }
    return dates.isNotEmpty ? dates : [_dueDate];
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppTheme.error : AppTheme.success,
      behavior: SnackBarBehavior.floating,
    ));
  }
}
