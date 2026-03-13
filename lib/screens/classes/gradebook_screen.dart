// lib/screens/classes/gradebook_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
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
  // When true, show all items as complete/incomplete even if grading mode is percent
  bool _simpleView = false;
  String _filterStudentUid = ''; // empty = all
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
            .orderBy('order')
            .get();
        allHw.addAll(hwSnap.docs
            .map((d) => HomeworkModel.fromMap(d.data(), d.id, cls.id, week.id)));
      }
      _allHomework = allHw;

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

      // Build per-student data
      final studentUids = widget.classModel.enrolledUids;
      // Get student names from Firestore
      final Map<String, String> studentNames = {};
      for (final uid in studentUids) {
        try {
          final doc = await _db.collection('users').doc(uid).get();
          studentNames[uid] = doc.data()?['displayName'] as String? ?? uid;
        } catch (_) {
          studentNames[uid] = uid;
        }
      }

      // Build rows
      final rows = <Map<String, dynamic>>[];
      for (final uid in studentUids) {
        double totalPct = 0;
        int countGraded = 0;
        int countSubmitted = 0;
        final hwGrades = <String, dynamic>{};
        for (final hw in allHw) {
          final sub = hwToStudentSub[hw.id]?[uid];
          if (sub == null) {
            hwGrades[hw.id] = null; // not submitted
          } else if (sub.status == 'graded' && hw.gradingMode == 'percent') {
            hwGrades[hw.id] = sub.grade;
            countGraded++;
            if (sub.grade != null) {
              final pct = hw.maxPoints != null && hw.maxPoints! > 0
                  ? (sub.grade! / hw.maxPoints!) * 100
                  : sub.grade!;
              totalPct += pct;
            }
          } else {
            final done = sub.status == 'submitted' || sub.status == 'graded';
            hwGrades[hw.id] = done ? 'done' : 'pending';
            if (done) countSubmitted++;
          }
        }
        final completionPct = allHw.isEmpty
            ? 0.0
            : (countSubmitted + countGraded) / allHw.length * 100;
        final avgGrade = countGraded > 0 ? totalPct / countGraded : null;

        rows.add({
          'uid': uid,
          'name': studentNames[uid] ?? uid,
          'hwGrades': hwGrades,
          'completionPct': completionPct,
          'avgGrade': avgGrade,
        });
      }

      // Sort by name
      rows.sort((a, b) =>
          (a['name'] as String).compareTo(b['name'] as String));

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
              style: pw.TextStyle(
                  fontSize: 18, fontWeight: pw.FontWeight.bold)),
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
          headerStyle:
              pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 9),
        ),
      ],
    ));

    await Printing.layoutPdf(
        onLayout: (format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    final cls = widget.classModel;
    final user = widget.user;
    final canView = user.canMentor || user.isAdmin ||
        (user.isStudent && !cls.gradebookSimple);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Gradebook · ${cls.shortname}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (user.canMentor || user.isAdmin) ...[
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
              child: Text('Gradebook is not available for your role.',
                  style: TextStyle(color: AppTheme.textSecondary)))
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // Toggle simple view
                    Container(
                      color: AppTheme.surface,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          const Text('View:',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary)),
                          const SizedBox(width: 12),
                          ChoiceChip(
                            label: const Text('Complete/Incomplete'),
                            selected: _simpleView,
                            onSelected: (_) => setState(() => _simpleView = true),
                            selectedColor:
                                AppTheme.classesColor.withValues(alpha: 0.2),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Grades'),
                            selected: !_simpleView,
                            onSelected: (_) =>
                                setState(() => _simpleView = false),
                            selectedColor:
                                AppTheme.classesColor.withValues(alpha: 0.2),
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
                          : _buildTable(),
                    ),
                  ],
                ),
    );
  }

  Widget _buildTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppTheme.navy.withValues(alpha: 0.08)),
          columnSpacing: 14,
          dataRowMinHeight: 40,
          dataRowMaxHeight: 52,
          columns: [
            const DataColumn(
                label: Text('Student',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navy))),
            const DataColumn(
                numeric: true,
                label: Text('Done %',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navy))),
            if (!_simpleView)
              const DataColumn(
                  numeric: true,
                  label: Text('Avg',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.navy))),
            ..._allHomework.map((hw) => DataColumn(
                label: SizedBox(
                  width: 70,
                  child: Text(
                    hw.title,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navy),
                  ),
                ))),
          ],
          rows: _gradebookData.map((row) {
            final pct = (row['completionPct'] as double);
            final avg = row['avgGrade'] as double?;
            final hwGrades = row['hwGrades'] as Map<String, dynamic>;
            return DataRow(cells: [
              DataCell(Text(row['name'] as String,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500))),
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
  const _GradeCell(
      {required this.grade,
      required this.gradingMode,
      required this.simpleView,
      required this.cls});

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
    // Numeric grade
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
