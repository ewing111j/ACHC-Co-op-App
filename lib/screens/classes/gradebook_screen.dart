// lib/screens/classes/gradebook_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/user_model.dart';
import '../../models/class_models.dart';
import '../../utils/app_theme.dart';

class GradebookScreen extends StatefulWidget {
  final ClassModel classModel;
  final UserModel user;
  const GradebookScreen({super.key, required this.classModel, required this.user});

  @override
  State<GradebookScreen> createState() => _GradebookScreenState();
}

class _GradebookScreenState extends State<GradebookScreen> {
  final _db = FirebaseFirestore.instance;
  bool _simpleView = false;
  bool _loading = true;
  List<Map<String, dynamic>> _gradebookData = [];
  List<HomeworkModel> _allHomework = [];

  @override
  void initState() {
    super.initState();
    _simpleView = widget.classModel.gradebookSimple;
    _loadGradebook();
  }

  Future<void> _loadGradebook() async {
    setState(() => _loading = true);
    try {
      final cls = widget.classModel;
      // Get all weeks
      final weeksSnap = await _db
          .collection('classes')
          .doc(cls.id)
          .collection('weeks')
          .orderBy('weekStart')
          .get();
      final weeks = weeksSnap.docs
          .map((d) => ClassWeekModel.fromMap(d.data(), d.id, cls.id))
          .toList();

      // Get all homework across all weeks
      final List<HomeworkModel> allHw = [];
      for (final week in weeks) {
        final hwSnap = await _db
            .collection('classes')
            .doc(cls.id)
            .collection('weeks')
            .doc(week.id)
            .collection('homework')
            .get();
        final sorted = hwSnap.docs
            .map((d) => HomeworkModel.fromMap(d.data(), d.id, cls.id, week.id))
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        allHw.addAll(sorted);
      }
      _allHomework = allHw.where((h) => !h.isContent).toList();

      // Determine which student UIDs to show
      final allStudentUids = cls.enrolledUids;
      // For students: only their own UID
      final List<String> studentUids = widget.user.isStudent
          ? (allStudentUids.contains(widget.user.uid) ? [widget.user.uid] : [])
          : allStudentUids;

      // Get all submissions
      final Map<String, Map<String, SubmissionModel>> hwToStudentSub = {};
      for (final week in weeks) {
        for (final hw in allHw.where((h) => h.weekId == week.id)) {
          final subSnap = await _db
              .collection('classes')
              .doc(cls.id)
              .collection('weeks')
              .doc(week.id)
              .collection('homework')
              .doc(hw.id)
              .collection('submissions')
              .get();
          hwToStudentSub[hw.id] = {};
          for (final sub in subSnap.docs) {
            final s = SubmissionModel.fromMap(sub.data(), sub.id);
            hwToStudentSub[hw.id]![s.studentUid] = s;
          }
        }
      }

      // Get student names
      final Map<String, String> studentNames = {};
      for (final uid in studentUids) {
        try {
          final doc = await _db.collection('users').doc(uid).get();
          studentNames[uid] = doc.data()?['displayName'] as String? ?? uid;
        } catch (_) {
          studentNames[uid] = uid;
        }
      }

      // Build per-student rows
      final rows = <Map<String, dynamic>>[];
      // Separate HW by type (exclude content items from grading)
      final gradableHw = allHw.where((h) => !h.isContent).toList();
      final hwItems = gradableHw.where((h) => h.isHw).toList();
      final quizItems = gradableHw.where((h) => h.isQuiz).toList();
      final testItems = gradableHw.where((h) => h.isTest).toList();

      double calcCategoryAvg(List<HomeworkModel> items, String uid) {
        double total = 0;
        int count = 0;
        for (final hw in items) {
          final sub = hwToStudentSub[hw.id]?[uid];
          if (sub != null && sub.status == 'graded' && hw.gradingMode == 'percent') {
            final pct = hw.maxPoints != null && hw.maxPoints! > 0
                ? (sub.grade! / hw.maxPoints!) * 100
                : sub.grade ?? 0;
            total += pct;
            count++;
          } else if (sub != null && (sub.status == 'submitted' || sub.status == 'graded')) {
            total += 100; // complete = 100%
            count++;
          }
        }
        return count > 0 ? total / count : 0;
      }

      for (final uid in studentUids) {
        int countSubmitted = 0;
        int countGraded = 0;
        final hwGrades = <String, dynamic>{};
        for (final hw in allHw) {
          if (hw.isContent) continue; // skip content items
          final sub = hwToStudentSub[hw.id]?[uid];
          if (sub == null) {
            hwGrades[hw.id] = null;
          } else if (sub.status == 'graded' && hw.gradingMode == 'percent') {
            final grade = sub.grade;
            hwGrades[hw.id] = grade;
            countGraded++;
          } else {
            final done = sub.status == 'submitted' || sub.status == 'graded';
            hwGrades[hw.id] = done ? 'done' : 'pending';
            if (done) countSubmitted++;
          }
        }
        final completionPct = gradableHw.isEmpty
            ? 0.0
            : (countSubmitted + countGraded) / gradableHw.length * 100;

        // Weighted final grade
        double? weightedGrade;
        final hwAvg = hwItems.isEmpty ? null : calcCategoryAvg(hwItems, uid);
        final quizAvg = quizItems.isEmpty ? null : calcCategoryAvg(quizItems, uid);
        final testAvg = testItems.isEmpty ? null : calcCategoryAvg(testItems, uid);
        // Only compute weighted if at least one graded category exists
        if (hwAvg != null || quizAvg != null || testAvg != null) {
          double totalWeight = 0;
          double totalScore = 0;
          if (hwAvg != null && hwItems.isNotEmpty) {
            totalWeight += cls.weightHw;
            totalScore += hwAvg * cls.weightHw;
          }
          if (quizAvg != null && quizItems.isNotEmpty) {
            totalWeight += cls.weightQuiz;
            totalScore += quizAvg * cls.weightQuiz;
          }
          if (testAvg != null && testItems.isNotEmpty) {
            totalWeight += cls.weightTest;
            totalScore += testAvg * cls.weightTest;
          }
          if (totalWeight > 0) weightedGrade = totalScore / totalWeight;
        }

        rows.add({
          'uid': uid,
          'name': studentNames[uid] ?? uid,
          'hwGrades': hwGrades,
          'completionPct': completionPct,
          'avgGrade': weightedGrade,
          'hwAvg': hwAvg,
          'quizAvg': quizAvg,
          'testAvg': testAvg,
        });
      }

      rows.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

      if (mounted) {
        setState(() {
          _gradebookData = rows;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error loading gradebook: $e'),
            backgroundColor: AppTheme.error));
      }
    }
  }

  Future<void> _exportPdf() async {
    final cls = widget.classModel;
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.letter.landscape,
      build: (ctx) => [
        pw.Header(
          level: 0,
          child: pw.Text('${cls.name} – Gradebook',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        ),
        pw.Text(
            'Generated: ${DateFormat('MMM d, yyyy · h:mm a').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 12),
        pw.Table.fromTextArray(
          headers: [
            'Student',
            'Completion %',
            if (!_simpleView) 'Avg Grade',
            ..._allHomework.map((hw) => hw.title),
          ],
          data: _gradebookData.map((row) {
            final hwGrades = row['hwGrades'] as Map<String, dynamic>;
            return [
              row['name'] as String,
              '${(row['completionPct'] as double).toStringAsFixed(0)}%',
              if (!_simpleView)
                row['avgGrade'] != null
                    ? '${(row['avgGrade'] as double).toStringAsFixed(1)}%'
                    : 'N/A',
              ..._allHomework.map((hw) {
                final g = hwGrades[hw.id];
                if (g == null) return '–';
                if (g == 'done') return '✓';
                if (g == 'pending') return '○';
                return '${(g as double).toStringAsFixed(0)}%';
              }),
            ];
          }).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 9),
        ),
      ],
    ));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  void _openSubmissionView(HomeworkModel hw) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SubmissionViewSheet(
        hw: hw,
        classModel: widget.classModel,
        db: _db,
        onGraded: _loadGradebook,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cls = widget.classModel;
    final user = widget.user;
    final canMentor = user.canMentor || user.isAdmin;
    // Students can view their own grades unless gradebook is hidden
    final canView = canMentor || (user.isStudent && !cls.gradebookSimple);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Gradebook · ${cls.shortname}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (canMentor) ...[
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
              tooltip: 'Export PDF',
              onPressed: _exportPdf,
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: _loadGradebook,
            ),
          ],
        ],
      ),
      body: !canView
          ? const Center(
              child: Text('Grades are not available yet.',
                  style: TextStyle(color: AppTheme.textSecondary)))
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // Student notice
                    if (user.isStudent)
                      Container(
                        width: double.infinity,
                        color: AppTheme.classesColor.withValues(alpha: 0.08),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(children: [
                          Icon(Icons.lock_outline, size: 14,
                              color: AppTheme.classesColor.withValues(alpha: 0.7)),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text('You can see your own grades only.',
                                style: TextStyle(fontSize: 12,
                                    color: AppTheme.textSecondary)),
                          ),
                        ]),
                      ),
                    // Mentor hint for submission view
                    if (canMentor && _allHomework.isNotEmpty)
                      Container(
                        width: double.infinity,
                        color: AppTheme.navy.withValues(alpha: 0.05),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                                'Tap any assignment column header to view & grade submissions.',
                                style: TextStyle(fontSize: 11,
                                    color: AppTheme.textSecondary)),
                            const SizedBox(height: 4),
                            Text(
                                'Grade weights: HW ${cls.weightHw.round()}% · Quiz ${cls.weightQuiz.round()}% · Test ${cls.weightTest.round()}%',
                                style: const TextStyle(fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.navy)),
                          ],
                        ),
                      ),
                    // Toggle simple view
                    Container(
                      color: AppTheme.surface,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          const Text('View:',
                              style: TextStyle(
                                  fontSize: 13, color: AppTheme.textSecondary)),
                          const SizedBox(width: 12),
                          ChoiceChip(
                            label: const Text('Complete/Incomplete'),
                            selected: _simpleView,
                            onSelected: (_) => setState(() => _simpleView = true),
                            selectedColor: AppTheme.classesColor.withValues(alpha: 0.2),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Grades'),
                            selected: !_simpleView,
                            onSelected: (_) => setState(() => _simpleView = false),
                            selectedColor: AppTheme.classesColor.withValues(alpha: 0.2),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: _gradebookData.isEmpty
                          ? const Center(
                              child: Text('No student data.',
                                  style: TextStyle(color: AppTheme.textSecondary)))
                          : _buildTable(canMentor),
                    ),
                  ],
                ),
    );
  }

  Widget _buildTable(bool canMentor) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
              AppTheme.navy.withValues(alpha: 0.08)),
          columnSpacing: 14,
          dataRowMinHeight: 40,
          dataRowMaxHeight: 52,
          columns: [
            const DataColumn(
                label: Text('Student',
                    style: TextStyle(fontSize: 12,
                        fontWeight: FontWeight.bold, color: AppTheme.navy))),
            const DataColumn(
                numeric: true,
                label: Text('Done %',
                    style: TextStyle(fontSize: 12,
                        fontWeight: FontWeight.bold, color: AppTheme.navy))),
            if (!_simpleView)
              const DataColumn(
                  numeric: true,
                  label: Text('Weighted\nGrade',
                      style: TextStyle(fontSize: 12,
                          fontWeight: FontWeight.bold, color: AppTheme.navy))),
            ..._allHomework.map((hw) => DataColumn(
                label: canMentor
                    ? InkWell(
                        onTap: () => _openSubmissionView(hw),
                        child: SizedBox(
                          width: 70,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(hw.title,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.navy)),
                              Row(children: [
                                _ItemTypeBadge(hw.itemType),
                                const SizedBox(width: 4),
                                const Text('tap',
                                    style: TextStyle(
                                        fontSize: 9,
                                        color: AppTheme.classesColor)),
                              ]),
                            ],
                          ),
                        ),
                      )
                    : SizedBox(
                        width: 70,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(hw.title,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.navy)),
                            _ItemTypeBadge(hw.itemType),
                          ],
                        ),
                      ))),
          ],
          rows: _gradebookData.map((row) {
            final pct = (row['completionPct'] as double);
            final avg = row['avgGrade'] as double?;
            final hwGrades = row['hwGrades'] as Map<String, dynamic>;
            return DataRow(cells: [
              DataCell(Text(row['name'] as String,
                  style: const TextStyle(fontSize: 12,
                      fontWeight: FontWeight.w500))),
              DataCell(_ProgressCell(pct: pct)),
              if (!_simpleView)
                DataCell(Text(
                  avg != null ? '${avg.toStringAsFixed(1)}%' : '–',
                  style: TextStyle(
                      fontSize: 12,
                      color: avg != null
                          ? _gradeColor(avg, widget.classModel)
                          : AppTheme.textTertiary),
                )),
              ..._allHomework.map((hw) {
                final g = hwGrades[hw.id];
                return DataCell(_GradeCell(
                    grade: g,
                    gradingMode: hw.gradingMode,
                    simpleView: _simpleView,
                    cls: widget.classModel));
              }),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Color _gradeColor(double pct, ClassModel cls) {
    if (pct >= 90) return Colors.green;
    if (pct >= 80) return Colors.orange;
    return Colors.red;
  }
}

// ── Item type badge ───────────────────────────────────────────────────────────
class _ItemTypeBadge extends StatelessWidget {
  final String itemType;
  const _ItemTypeBadge(this.itemType);

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (itemType) {
      case 'quiz':
        color = AppTheme.classesColor;
        label = 'Quiz';
        break;
      case 'test':
        color = AppTheme.mandatoryRed;
        label = 'Test';
        break;
      default:
        color = AppTheme.assignmentsColor;
        label = 'HW';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 8, color: color, fontWeight: FontWeight.w700)),
    );
  }
}

/// Mentor/admin view: lists all students' submissions for a given homework,
/// and allows entering grades inline.
class _SubmissionViewSheet extends StatefulWidget {
  final HomeworkModel hw;
  final ClassModel classModel;
  final FirebaseFirestore db;
  final VoidCallback onGraded;

  const _SubmissionViewSheet({
    required this.hw,
    required this.classModel,
    required this.db,
    required this.onGraded,
  });

  @override
  State<_SubmissionViewSheet> createState() => _SubmissionViewSheetState();
}

class _SubmissionViewSheetState extends State<_SubmissionViewSheet> {
  bool _loading = true;
  List<_StudentSubmission> _items = [];

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  Future<void> _loadSubmissions() async {
    setState(() => _loading = true);
    try {
      final hw = widget.hw;
      final cls = widget.classModel;
      final db = widget.db;

      // Get all students
      final Map<String, String> names = {};
      for (final uid in cls.enrolledUids) {
        try {
          final doc = await db.collection('users').doc(uid).get();
          names[uid] = doc.data()?['displayName'] as String? ?? uid;
        } catch (_) {
          names[uid] = uid;
        }
      }

      // Get submissions
      final subSnap = await db
          .collection('classes')
          .doc(cls.id)
          .collection('weeks')
          .doc(hw.weekId)
          .collection('homework')
          .doc(hw.id)
          .collection('submissions')
          .get();

      final Map<String, SubmissionModel> subByUid = {};
      for (final doc in subSnap.docs) {
        final s = SubmissionModel.fromMap(doc.data(), doc.id);
        subByUid[s.studentUid] = s;
      }

      final items = cls.enrolledUids.map((uid) {
        return _StudentSubmission(
          uid: uid,
          name: names[uid] ?? uid,
          submission: subByUid[uid],
        );
      }).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hw = widget.hw;
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, ctrl) => Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: AppTheme.dividerColor,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(children: [
                const Icon(Icons.assignment_turned_in_outlined,
                    color: AppTheme.navy, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(hw.title,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.navy)),
                      Text(
                          '${_items.where((i) => i.submission?.isComplete == true).length}/${_items.length} submitted',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ]),
            ),
            AppTheme.goldDivider(),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: ListView.separated(
                  controller: ctrl,
                  padding: const EdgeInsets.all(12),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => _SubmissionTile(
                    item: _items[i],
                    hw: hw,
                    classModel: widget.classModel,
                    db: widget.db,
                    onGraded: () {
                      _loadSubmissions();
                      widget.onGraded();
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StudentSubmission {
  final String uid;
  final String name;
  final SubmissionModel? submission;
  const _StudentSubmission({required this.uid, required this.name, this.submission});
}

class _SubmissionTile extends StatefulWidget {
  final _StudentSubmission item;
  final HomeworkModel hw;
  final ClassModel classModel;
  final FirebaseFirestore db;
  final VoidCallback onGraded;

  const _SubmissionTile({
    required this.item,
    required this.hw,
    required this.classModel,
    required this.db,
    required this.onGraded,
  });

  @override
  State<_SubmissionTile> createState() => _SubmissionTileState();
}

class _SubmissionTileState extends State<_SubmissionTile> {
  bool _expanded = false;
  bool _saving = false;
  double? _gradeInput;
  late TextEditingController _feedbackCtrl;
  late TextEditingController _gradeCtrl;

  @override
  void initState() {
    super.initState();
    _gradeInput = widget.item.submission?.grade;
    _feedbackCtrl = TextEditingController(
        text: widget.item.submission?.feedback ?? '');
    _gradeCtrl = TextEditingController(
        text: _gradeInput?.toString() ?? '');
  }

  @override
  void dispose() {
    _feedbackCtrl.dispose();
    _gradeCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveGrade() async {
    final sub = widget.item.submission;
    if (sub == null) return;
    setState(() => _saving = true);
    try {
      await widget.db
          .collection('classes')
          .doc(widget.classModel.id)
          .collection('weeks')
          .doc(widget.hw.weekId)
          .collection('homework')
          .doc(widget.hw.id)
          .collection('submissions')
          .doc(sub.id)
          .update({
        'grade': _gradeInput,
        'feedback': _feedbackCtrl.text.trim(),
        'status': 'graded',
        'gradedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        setState(() { _saving = false; _expanded = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Grade saved'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating));
        widget.onGraded();
      }
    } catch (e) {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _markComplete() async {
    final sub = widget.item.submission;
    if (sub == null) return;
    setState(() => _saving = true);
    try {
      await widget.db
          .collection('classes')
          .doc(widget.classModel.id)
          .collection('weeks')
          .doc(widget.hw.weekId)
          .collection('homework')
          .doc(widget.hw.id)
          .collection('submissions')
          .doc(sub.id)
          .update({
        'status': 'graded',
        'gradedAt': FieldValue.serverTimestamp(),
        'feedback': _feedbackCtrl.text.trim(),
      });
      if (mounted) {
        setState(() { _saving = false; _expanded = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Marked as complete'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating));
        widget.onGraded();
      }
    } catch (e) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = widget.item.submission;
    final isSubmitted = sub?.isComplete == true;
    final isGraded = sub?.status == 'graded';

    Color statusColor;
    String statusLabel;
    if (sub == null) {
      statusColor = Colors.grey;
      statusLabel = 'Not submitted';
    } else if (isGraded) {
      statusColor = AppTheme.success;
      statusLabel = 'Graded';
    } else if (isSubmitted) {
      statusColor = AppTheme.classesColor;
      statusLabel = 'Submitted';
    } else {
      statusColor = Colors.orange;
      statusLabel = 'Pending';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: statusColor.withValues(alpha: 0.12),
            child: Text(
              widget.item.name.isNotEmpty ? widget.item.name[0].toUpperCase() : '?',
              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          title: Text(widget.item.name,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: sub != null
              ? Text(
                  '${statusLabel}${sub.grade != null ? ' · ${sub.grade!.toStringAsFixed(1)}' : ''}',
                  style: TextStyle(fontSize: 11, color: statusColor))
              : Text(statusLabel,
                  style: TextStyle(fontSize: 11, color: statusColor)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Download file if present
              if (sub?.fileUrl != null)
                IconButton(
                  icon: const Icon(Icons.download_outlined, size: 18,
                      color: AppTheme.navy),
                  tooltip: 'Download: ${sub!.fileName ?? 'file'}',
                  onPressed: () async {
                    final url = sub.fileUrl!;
                    if (await canLaunchUrl(Uri.parse(url))) {
                      await launchUrl(Uri.parse(url),
                          mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              if (sub != null)
                IconButton(
                  icon: Icon(
                    _expanded ? Icons.expand_less : Icons.grade_outlined,
                    size: 18,
                    color: AppTheme.navy,
                  ),
                  tooltip: 'Grade',
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
            ],
          ),
        ),
        // Expandable grading panel
        if (_expanded && sub != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.navy.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Checklist items if any
                  if (widget.hw.checklist.isNotEmpty) ...[
                    const Text('Checklist',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.navy)),
                    const SizedBox(height: 4),
                    ...widget.hw.checklist.map((item) {
                      // checklistDone keys are the item text strings
                      final done = sub.checklistDone[item] ?? false;
                      return Row(children: [
                        Icon(done ? Icons.check_box : Icons.check_box_outline_blank,
                            size: 14,
                            color: done ? AppTheme.success : Colors.grey),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(item,
                                style: const TextStyle(fontSize: 12))),
                      ]);
                    }),
                    const SizedBox(height: 8),
                  ],
                  // File attached
                  if (sub.fileUrl != null) ...[
                    InkWell(
                      onTap: () async {
                        final url = sub.fileUrl!;
                        if (await canLaunchUrl(Uri.parse(url))) {
                          await launchUrl(Uri.parse(url),
                              mode: LaunchMode.externalApplication);
                        }
                      },
                      child: Row(children: [
                        const Icon(Icons.attach_file, size: 14,
                            color: AppTheme.navy),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(sub.fileName ?? 'Attached file',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.navy,
                                  decoration: TextDecoration.underline)),
                        ),
                        const Icon(Icons.open_in_new, size: 12,
                            color: AppTheme.navy),
                      ]),
                    ),
                    const SizedBox(height: 8),
                  ],
                  // Grade input (percent mode)
                  if (widget.hw.gradingMode == 'percent') ...[
                    TextField(
                      controller: _gradeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: widget.hw.maxPoints != null
                            ? 'Points (max ${widget.hw.maxPoints})'
                            : 'Percentage (0–100)',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (v) => _gradeInput = double.tryParse(v),
                    ),
                    const SizedBox(height: 8),
                  ],
                  // Feedback
                  TextField(
                    controller: _feedbackCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Feedback (optional)',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    if (widget.hw.gradingMode == 'percent')
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _saveGrade,
                          icon: _saving
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.check, size: 16),
                          label: const Text('Save Grade'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.navy,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10)),
                        ),
                      )
                    else
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _markComplete,
                          icon: _saving
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.check_circle, size: 16),
                          label: const Text('Mark Complete'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.success,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10)),
                        ),
                      ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => setState(() => _expanded = false),
                      child: const Text('Cancel'),
                    ),
                  ]),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ── Shared helper widgets ─────────────────────────────────────────────────────

class _ProgressCell extends StatelessWidget {
  final double pct;
  const _ProgressCell({required this.pct});

  @override
  Widget build(BuildContext context) {
    Color color;
    if (pct >= 95) {
      color = Colors.green;
    } else if (pct >= 90) {
      color = Colors.lightGreen;
    } else if (pct >= 80) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 4),
        Text('${pct.toStringAsFixed(0)}%',
            style: TextStyle(
                fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _GradeCell extends StatelessWidget {
  final dynamic grade;
  final String gradingMode;
  final bool simpleView;
  final ClassModel cls;
  const _GradeCell({
    required this.grade,
    required this.gradingMode,
    required this.simpleView,
    required this.cls,
  });

  @override
  Widget build(BuildContext context) {
    if (grade == null) {
      return const Text('–',
          style: TextStyle(fontSize: 12, color: AppTheme.textTertiary));
    }
    if (grade == 'done' || simpleView) {
      final isDone = grade == 'done' || grade is double;
      return Icon(isDone ? Icons.check_circle : Icons.circle_outlined,
          size: 16,
          color: isDone ? Colors.green : Colors.grey);
    }
    if (grade == 'pending') {
      return const Icon(Icons.circle_outlined, size: 16, color: Colors.grey);
    }
    final g = grade as double;
    final pct = cls.maxPct(g);
    return Text('${pct.toStringAsFixed(0)}%',
        style: TextStyle(
            fontSize: 12,
            color: _gradeColor(pct),
            fontWeight: FontWeight.w600));
  }

  Color _gradeColor(double pct) {
    if (pct >= 90) return Colors.green;
    if (pct >= 80) return Colors.orange;
    return Colors.red;
  }
}
