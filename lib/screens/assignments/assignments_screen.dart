// lib/screens/assignments/assignments_screen.dart
// Enhanced: student selector, weekly summary per class, color-coded, checkboxes,
// printable PDFs, parent deadline notifications, full sync Firebase/Moodle
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../providers/auth_provider.dart';
import '../../models/assignment_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../services/moodle_service.dart';
import '../../utils/app_theme.dart';
import '../moodle/moodle_setup_screen.dart';
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
  String? _selectedKidUid; // parent selects which kid to view
  UserModel? _selectedStudent;
  List<UserModel> _students = [];
  bool _weeklyView = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _init();
    });
  }

  Future<void> _init() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    if (user.moodleUrl != null && user.moodleToken != null) {
      _moodleService.configure(user.moodleUrl!, user.moodleToken!);
    }
    if (user.isParent || user.isAdmin) {
      await _loadStudents(user);
    }
  }

  Future<void> _loadStudents(UserModel user) async {
    if (user.kidUids.isEmpty) return;
    final futures = user.kidUids.map((uid) => _db.collection('users').doc(uid).get());
    final docs = await Future.wait(futures);
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
        _showSnack('Could not connect to Moodle. Check your settings.', isError: true);
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
    Navigator.push(context, MaterialPageRoute(builder: (_) => const MoodleSetupScreen()));
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppTheme.error : AppTheme.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _printAssignments(BuildContext context, UserModel user) async {
    // Get current student name
    final studentName = _selectedStudent?.displayName ?? user.displayName;
    final familyId = user.familyId ?? '';
    final viewUid = user.isStudent ? user.uid : (_selectedKidUid ?? user.uid);

    // Fetch assignments
    List<AssignmentModel> assignments = [];
    try {
      final snap = await FirebaseFirestore.instance
          .collection('assignments')
          .where('familyId', isEqualTo: familyId)
          .get();
      assignments = snap.docs
          .map((d) => AssignmentModel.fromMap(d.data(), d.id))
          .where((a) => a.assignedTo == viewUid || a.assignedTo == null || a.assignedTo!.isEmpty || a.assignedTo == 'all')
          .toList();
      assignments.sort((a, b) => a.dueDate != null && b.dueDate != null
          ? a.dueDate!.compareTo(b.dueDate!)
          : 0);
    } catch (e) {
      _showSnack('Could not load assignments for print', isError: true);
      return;
    }

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        build: (pw.Context ctx) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text(
                'Assignments – $studentName',
                style: pw.TextStyle(
                    fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Printed: ${DateFormat('MMMM d, y').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 16),
            if (assignments.isEmpty)
              pw.Text('No assignments found.',
                  style: const pw.TextStyle(fontSize: 12))
            else
              ...assignments.map((a) {
                final status = a.status.name;
                final done = a.status == AssignmentStatus.submitted ||
                    a.status == AssignmentStatus.graded;
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 8),
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        done ? '[✓]' : '[ ]',
                        style: pw.TextStyle(
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold),
                      ),
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
                                  style: const pw.TextStyle(
                                      fontSize: 11)),
                            if (a.dueDate != null)
                              pw.Text(
                                'Due: ${DateFormat('MMM d, y').format(a.dueDate!)}',
                                style: pw.TextStyle(
                                    fontSize: 11,
                                    color: done
                                        ? PdfColors.green700
                                        : PdfColors.red700),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: 'Assignments_$studentName.pdf',
    );
  }
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser!;
    final familyId = user.familyId ?? '';

    // Determine whose assignments to show
    final viewUid = user.isStudent
        ? user.uid
        : (_selectedKidUid ?? user.uid);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Assignments'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!user.isStudent)
            IconButton(
              icon: Icon(_weeklyView ? Icons.view_list : Icons.calendar_view_week),
              tooltip: _weeklyView ? 'List View' : 'Weekly View',
              onPressed: () => setState(() => _weeklyView = !_weeklyView),
            ),
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Print Assignments',
            onPressed: () => _printAssignments(context, user),
          ),
          if (user.isParent || user.isAdmin)
            IconButton(
              icon: _isSyncing
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.sync),
              tooltip: 'Sync from Moodle',
              onPressed: _isSyncing ? null : _syncMoodle,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Done'),
            Tab(text: 'All'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Student Selector (parents only)
          if ((user.isParent || user.isAdmin) && _students.isNotEmpty)
            _buildKidSelector(),
          // Assignments List
          Expanded(
            child: StreamBuilder<List<AssignmentModel>>(
              stream: _firestoreService.streamAssignments(familyId, viewUid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}',
                        style: const TextStyle(color: AppTheme.error)),
                  );
                }
                final all = snapshot.data ?? [];
                final pending = all.where((a) =>
                    a.status == AssignmentStatus.pending || a.isOverdue).toList();
                final done = all.where((a) =>
                    a.status == AssignmentStatus.submitted ||
                    a.status == AssignmentStatus.graded).toList();

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBody(pending, 'No pending assignments! 🎉', user, familyId),
                    _buildBody(done, 'No completed assignments yet', user, familyId),
                    _buildBody(all, 'No assignments found', user, familyId),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: (user.isParent || user.isAdmin)
          ? FloatingActionButton.extended(
              onPressed: () => _showAddDialog(context, user, familyId),
              icon: const Icon(Icons.add),
              label: const Text('Add Task'),
              backgroundColor: AppTheme.assignmentsColor,
            )
          : null,
    );
  }

  Widget _buildKidSelector() {
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
              onTap: () => setState(() {
                _selectedKidUid = null;
                _selectedStudent = null;
              }),
            ),
            ..._students.map((student) => _KidChip(
              label: student.displayName,  // Full name
              isSelected: _selectedKidUid == student.uid,
              onTap: () => setState(() {
                _selectedKidUid = student.uid;
                _selectedStudent = student;
              }),
            )),
          ],
        ),
      ),
    );
  }

  Map<String, String> _buildKidNames() {
    final map = <String, String>{};
    for (final k in _students) { map[k.uid] = k.displayName; }
    return map;
  }

  Widget _buildBody(
      List<AssignmentModel> assignments, String emptyMsg, UserModel user, String familyId) {
    if (assignments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment_outlined, size: 64, color: AppTheme.textHint),
            const SizedBox(height: 16),
            Text(emptyMsg,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
            if (!_moodleService.isConfigured && !user.isStudent) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _showMoodleSetup,
                icon: const Icon(Icons.link),
                label: const Text('Connect Moodle'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.assignmentsColor),
              ),
            ],
          ],
        ),
      );
    }

    final kidNames = _buildKidNames();

    if (_weeklyView && !user.isStudent) {
      return _WeeklyView(assignments: assignments, user: user, db: _db, kidNames: kidNames);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: assignments.length,
      itemBuilder: (ctx, i) => _AssignmentCard(
        assignment: assignments[i],
        user: user,
        db: _db,
        isStudentView: user.isStudent,
        kidNames: kidNames,
      ),
    );
  }

  void _showAddDialog(BuildContext context, UserModel user, String familyId) {
    final kidInfos = _students.map((k) => _KidInfo(uid: k.uid, name: k.displayName)).toList();
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
  }
}

// ── Kid Chip ──────────────────────────────────────────────────────
class _KidChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _KidChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.navy : AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? AppTheme.navy : AppTheme.cardBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── Assignment Card ───────────────────────────────────────────────
class _AssignmentCard extends StatelessWidget {
  final AssignmentModel assignment;
  final UserModel user;
  final FirebaseFirestore db;
  final bool isStudentView;
  final Map<String, String> kidNames; // uid → name
  const _AssignmentCard({
    required this.assignment,
    required this.user,
    required this.db,
    required this.isStudentView,
    this.kidNames = const {},
  });

  @override
  Widget build(BuildContext context) {
    final a = assignment;
    final isOverdue = a.isOverdue;
    final isMandatory = !a.isOptional;
    final statusColor = isOverdue
        ? AppTheme.error
        : isMandatory
            ? AppTheme.mandatoryRed
            : AppTheme.optionalGreen;

    // Determine assigned-to name
    String? assignedName;
    if (a.assignedTo != null && a.assignedTo != 'all') {
      assignedName = kidNames[a.assignedTo] ?? a.assignedTo;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: isMandatory ? AppTheme.mandatoryRed : AppTheme.optionalGreen,
            width: 4,
          ),
          top: BorderSide(color: AppTheme.cardBorder),
          right: BorderSide(color: AppTheme.cardBorder),
          bottom: BorderSide(color: AppTheme.cardBorder),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox
            GestureDetector(
              onTap: () => _toggleStatus(context),
              child: Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: statusColor, width: 2),
                  color: a.status == AssignmentStatus.submitted ||
                          a.status == AssignmentStatus.graded
                      ? statusColor.withValues(alpha: 0.15)
                      : Colors.transparent,
                ),
                child: a.status == AssignmentStatus.submitted ||
                        a.status == AssignmentStatus.graded
                    ? Icon(Icons.check, size: 14, color: statusColor)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          a.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                            decoration: a.status == AssignmentStatus.graded
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                      if (a.fromMoodle)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.info.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Moodle',
                              style: TextStyle(color: AppTheme.info, fontSize: 10)),
                        ),
                      // Edit/Delete menu for non-Moodle tasks
                      if (!a.fromMoodle && (user.isAdmin || user.isParent))
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert,
                              size: 16, color: AppTheme.textHint),
                          onSelected: (v) {
                            if (v == 'edit') {
                              _showEditSheet(context);
                            } else if (v == 'delete') {
                              _confirmDelete(context);
                            }
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
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(a.courseName,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                  // Show who it's assigned to
                  if (assignedName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.person_outlined,
                              size: 12, color: AppTheme.navy),
                          const SizedBox(width: 3),
                          Text(assignedName,
                              style: const TextStyle(
                                  color: AppTheme.navy,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  if (a.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(a.description,
                        style: const TextStyle(
                            color: AppTheme.textHint, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 12,
                          color: isOverdue ? AppTheme.error : AppTheme.textHint),
                      const SizedBox(width: 4),
                      Text(
                        'Due ${DateFormat('MMM d').format(a.dueDate)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isOverdue ? AppTheme.error : AppTheme.textHint,
                          fontWeight:
                              isOverdue ? FontWeight.w700 : FontWeight.normal,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isMandatory
                                  ? AppTheme.mandatoryRed
                                  : AppTheme.optionalGreen)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isMandatory ? '● Required' : '○ Optional',
                          style: TextStyle(
                            fontSize: 10,
                            color: isMandatory
                                ? AppTheme.mandatoryRed
                                : AppTheme.optionalGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleStatus(BuildContext context) {
    final newStatus = assignment.status == AssignmentStatus.pending ||
            assignment.status == AssignmentStatus.overdue
        ? AssignmentStatus.submitted
        : AssignmentStatus.pending;
    db.collection('assignments').doc(assignment.id).update({
      'status': newStatus.name,
    });
  }

  void _showEditSheet(BuildContext context) {
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
              await db.collection('assignments').doc(assignment.id).delete();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Kid Info helper ───────────────────────────────────────────────
class _KidInfo {
  final String uid;
  final String name;
  const _KidInfo({required this.uid, required this.name});
}

// ── Weekly View ───────────────────────────────────────────────────
class _WeeklyView extends StatefulWidget {
  final List<AssignmentModel> assignments;
  final UserModel user;
  final FirebaseFirestore db;
  final Map<String, String> kidNames;
  const _WeeklyView({
    required this.assignments,
    required this.user,
    required this.db,
    required this.kidNames,
  });

  @override
  State<_WeeklyView> createState() => _WeeklyViewState();
}

class _WeeklyViewState extends State<_WeeklyView> {
  int _weekOffset = 0; // 0 = current week, -1 = last week, etc.

  DateTime get _weekStart {
    final now = DateTime.now().add(Duration(days: _weekOffset * 7));
    final dayOfWeek = now.weekday; // Mon=1, Sun=7
    return DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: dayOfWeek - 1));
  }

  DateTime get _weekEnd => _weekStart.add(const Duration(days: 6));

  String get _weekLabel {
    final fmt = DateFormat('MMM d');
    return 'Week of ${fmt.format(_weekStart)} – ${fmt.format(_weekEnd)}';
  }

  List<AssignmentModel> get _filteredAssignments {
    final start = _weekStart;
    final end = _weekEnd.add(const Duration(days: 1));
    return widget.assignments
        .where((a) =>
            a.dueDate.isAfter(start.subtract(const Duration(seconds: 1))) &&
            a.dueDate.isBefore(end))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final weekAssignments = _filteredAssignments;

    // Group by course
    final Map<String, List<AssignmentModel>> byCourse = {};
    for (final a in weekAssignments) {
      byCourse.putIfAbsent(a.courseName, () => []).add(a);
    }

    return Column(
      children: [
        // Week navigation header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppTheme.surface,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() => _weekOffset--),
                tooltip: 'Previous week',
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(_weekLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppTheme.textPrimary)),
                    Text('${weekAssignments.length} tasks',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textHint)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _weekOffset >= 0
                    ? null
                    : () => setState(() => _weekOffset++),
                tooltip: 'Next week',
              ),
            ],
          ),
        ),
        AppTheme.goldDivider(),
        Expanded(
          child: weekAssignments.isEmpty
              ? Center(
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
                      Text(_weekLabel,
                          style: const TextStyle(
                              color: AppTheme.textHint, fontSize: 12)),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: byCourse.entries.map((entry) {
                    final course = entry.key;
                    final courseAssignments = entry.value;
                    final pending = courseAssignments
                        .where((a) => a.status == AssignmentStatus.pending)
                        .length;
                    final done = courseAssignments.length - pending;

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
                          initiallyExpanded: true,
                          tilePadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(course,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textPrimary)),
                              ),
                              if (pending > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.mandatoryRed
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text('$pending pending',
                                      style: const TextStyle(
                                          color: AppTheme.mandatoryRed,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600)),
                                ),
                              const SizedBox(width: 8),
                              Text('$done done',
                                  style: const TextStyle(
                                      color: AppTheme.optionalGreen,
                                      fontSize: 11)),
                            ],
                          ),
                          children: courseAssignments
                              .map((a) => _AssignmentCard(
                                    assignment: a,
                                    user: widget.user,
                                    db: widget.db,
                                    isStudentView: false,
                                    kidNames: widget.kidNames,
                                  ))
                              .toList(),
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

// ── Add / Edit Assignment Sheet ───────────────────────────────────
class _AddAssignmentSheet extends StatefulWidget {
  final UserModel user;
  final String familyId;
  final List<_KidInfo> kids;
  final FirebaseFirestore db;
  final AssignmentModel? editAssignment; // null = add mode
  const _AddAssignmentSheet({
    required this.user,
    required this.familyId,
    required this.kids,
    required this.db,
    this.editAssignment,
  });

  @override
  State<_AddAssignmentSheet> createState() => _AddAssignmentSheetState();
}

class _AddAssignmentSheetState extends State<_AddAssignmentSheet> {
  final _titleCtrl = TextEditingController();
  final _courseCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  bool _isOptional = false;
  String _assignTo = 'all';
  bool _saving = false;

  // Repeat
  String _repeatMode = 'none'; // none | daily | weekly | custom
  final Map<int, bool> _repeatDays = {
    1: false, // Mon
    2: false, // Tue
    3: false, // Wed
    4: false, // Thu
    5: false, // Fri
  };

  bool get _isEdit => widget.editAssignment != null;

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
    super.dispose();
  }

  static const _dayLabels = {1: 'M', 2: 'T', 3: 'W', 4: 'Th', 5: 'F'};
  static const _dayFullLabels = {
    1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri'
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(_isEdit ? 'Edit Assignment' : 'Add Assignment',
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),
                  const Spacer(),
                  IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                    labelText: 'Title *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _courseCtrl,
                decoration: const InputDecoration(
                    labelText: 'Course / Subject',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
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
                title: Text('Due: ${DateFormat('MMM d, y').format(_dueDate)}',
                    style: const TextStyle(fontSize: 14)),
                trailing: const Icon(Icons.calendar_today,
                    size: 18, color: AppTheme.navy),
                onTap: () async {
                  final p = await showDatePicker(
                    context: context,
                    initialDate: _dueDate,
                    firstDate:
                        DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (p != null) setState(() => _dueDate = p);
                },
              ),
              // Optional toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Row(
                  children: [
                    Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(
                        color: _isOptional
                            ? AppTheme.optionalGreen
                            : AppTheme.mandatoryRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isOptional ? 'Optional (green)' : 'Mandatory (red)',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                value: _isOptional,
                activeThumbColor: AppTheme.optionalGreen,
                onChanged: (v) => setState(() => _isOptional = v),
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
                        value: 'all', child: Text('All Kids')),
                    ...widget.kids.map((k) => DropdownMenuItem(
                        value: k.uid, child: Text(k.name))),
                  ],
                  onChanged: (v) => setState(() => _assignTo = v ?? 'all'),
                ),
              const SizedBox(height: 12),
              // Repeat section (add mode only)
              if (!_isEdit) ...[
                const Divider(),
                Row(
                  children: [
                    const Text('Repeat',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    const Spacer(),
                    DropdownButton<String>(
                      value: _repeatMode,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'none', child: Text('No Repeat')),
                        DropdownMenuItem(value: 'daily', child: Text('Daily (M–F)')),
                        DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                        DropdownMenuItem(value: 'custom', child: Text('Custom Days')),
                      ],
                      onChanged: (v) {
                        setState(() {
                          _repeatMode = v ?? 'none';
                          if (v == 'daily') {
                            for (final k in _repeatDays.keys) {
                              _repeatDays[k] = true;
                            }
                          } else if (v != 'custom') {
                            for (final k in _repeatDays.keys) {
                              _repeatDays[k] = false;
                            }
                          }
                        });
                      },
                    ),
                  ],
                ),
                if (_repeatMode == 'custom')
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: _repeatDays.keys.map((day) {
                        final selected = _repeatDays[day]!;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _repeatDays[day] = !selected),
                          child: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: selected
                                  ? AppTheme.assignmentsColor
                                  : AppTheme.surfaceVariant,
                              border: Border.all(
                                  color: selected
                                      ? AppTheme.assignmentsColor
                                      : AppTheme.cardBorder),
                            ),
                            child: Center(
                              child: Text(_dayLabels[day]!,
                                  style: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          : AppTheme.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                if (_repeatMode != 'none')
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _repeatMode == 'weekly'
                          ? 'Creates a task every week on ${_dayFullLabels[_dueDate.weekday] ?? 'same day'}'
                          : _repeatMode == 'daily'
                              ? 'Creates tasks Mon–Fri for 4 weeks'
                              : 'Creates tasks on selected days for 4 weeks',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textHint),
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.assignmentsColor,
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: _saving
                      ? const CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2)
                      : Text(_isEdit ? 'Save Changes' : 'Add Assignment'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        // Update existing
        await widget.db
            .collection('assignments')
            .doc(widget.editAssignment!.id)
            .update({
          'title': _titleCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'courseName': _courseCtrl.text.trim().isEmpty
              ? 'General'
              : _courseCtrl.text.trim(),
          'dueDate': Timestamp.fromDate(_dueDate),
          'isOptional': _isOptional,
          'assignedTo': _assignTo,
        });
      } else {
        // Build list of dates based on repeat
        final dates = _buildDates();
        final batch = widget.db.batch();
        for (final date in dates) {
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
          });
        }
        await batch.commit();
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<DateTime> _buildDates() {
    if (_repeatMode == 'none') return [_dueDate];

    final dates = <DateTime>[];
    if (_repeatMode == 'weekly') {
      // Same weekday, 4 consecutive weeks
      for (int w = 0; w < 4; w++) {
        dates.add(_dueDate.add(Duration(days: w * 7)));
      }
    } else {
      // daily or custom — 4 weeks worth of selected days
      final activeDays = _repeatMode == 'daily'
          ? [1, 2, 3, 4, 5]
          : _repeatDays.entries
              .where((e) => e.value)
              .map((e) => e.key)
              .toList();
      if (activeDays.isEmpty) return [_dueDate];

      // Start from the week containing _dueDate
      final startDay = _dueDate;
      final monday = startDay.subtract(Duration(days: startDay.weekday - 1));
      for (int w = 0; w < 4; w++) {
        for (final dayNum in activeDays) {
          final date = monday.add(Duration(days: (w * 7) + (dayNum - 1)));
          if (!date.isBefore(startDay.subtract(const Duration(days: 1)))) {
            dates.add(date);
          }
        }
      }
    }
    return dates.isNotEmpty ? dates : [_dueDate];
  }
}
