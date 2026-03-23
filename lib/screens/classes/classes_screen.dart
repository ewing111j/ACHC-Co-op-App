// lib/screens/classes/classes_screen.dart
// Classes List — top-level home screen entry point
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../models/class_models.dart';
import '../../utils/app_theme.dart';
import 'class_dashboard_screen.dart';
import 'add_class_sheet.dart';
import 'google_sheet_import_screen.dart';

class ClassesScreen extends StatefulWidget {
  const ClassesScreen({super.key});
  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen> {
  final _db = FirebaseFirestore.instance;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text.toLowerCase()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser!;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Classes'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (user.isAdmin)
            IconButton(
              icon: const Icon(Icons.table_chart_outlined, size: 20),
              tooltip: 'Import from Google Sheet',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => GoogleSheetImportScreen(user: user))),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search classes…',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () => _searchCtrl.clear())
                    : null,
                isDense: true,
                filled: true,
                fillColor: AppTheme.surfaceVariant,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          AppTheme.goldDivider(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildQuery(user),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}',
                      style: const TextStyle(color: AppTheme.error)));
                }
                var classes = (snap.data?.docs ?? [])
                    .map((d) => ClassModel.fromMap(d.data() as Map<String, dynamic>, d.id))
                    .where((c) => !c.isArchived)
                    .toList();
                if (_query.isNotEmpty) {
                  classes = classes
                      .where((c) =>
                          c.name.toLowerCase().contains(_query) ||
                          c.shortname.toLowerCase().contains(_query))
                      .toList();
                }
                classes.sort((a, b) => a.name.compareTo(b.name));
                if (classes.isEmpty) {
                  return _EmptyClasses(canAdd: user.canEditClasses || user.isAdmin);
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: classes.length,
                  itemBuilder: (ctx, i) => _ClassCard(
                    cls: classes[i],
                    user: user,
                    db: _db,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => ClassDashboardScreen(
                                classModel: classes[i], user: user))),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: (user.canEditClasses || user.isAdmin)
          ? FloatingActionButton.extended(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => AddClassSheet(user: user, db: _db),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add Class'),
              backgroundColor: AppTheme.classesColor,
            )
          : null,
    );
  }

  Stream<QuerySnapshot> _buildQuery(UserModel user) {
    final col = _db.collection('classes');
    if (user.isAdmin) return col.snapshots();
    if (user.canMentor) {
      return col.where('mentorUids', arrayContains: user.uid).snapshots();
    }
    // Student or parent: see enrolled classes
    final uid = user.isStudent ? user.uid : null;
    if (uid != null) {
      return col.where('enrolledUids', arrayContains: uid).snapshots();
    }
    // Parent: show all (filter by kids happens in dashboard)
    return col.snapshots();
  }
}

// ── Class Card ────────────────────────────────────────────────────────────────
class _ClassCard extends StatelessWidget {
  final ClassModel cls;
  final UserModel user;
  final FirebaseFirestore db;
  final VoidCallback onTap;

  const _ClassCard({
    required this.cls,
    required this.user,
    required this.db,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(cls.colorValue);
    // Progress: fetch submission stats
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header stripe
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Color dot + shortname
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: color.withValues(alpha: 0.3)),
                        ),
                        child: Text(cls.shortname,
                            style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(cls.name,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary)),
                      ),
                      const Icon(Icons.chevron_right,
                          color: AppTheme.textHint, size: 18),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Mentor names
                  _MentorNames(mentorUids: cls.mentorUids, db: db),
                  const SizedBox(height: 10),
                  // Progress bar (student/parent view)
                  if (user.isStudent) ...[
                    _ProgressBar(
                        classId: cls.id,
                        studentUid: user.uid,
                        db: db,
                        color: color),
                    const SizedBox(height: 8),
                    _GradeIndicator(
                        classId: cls.id,
                        studentUid: user.uid,
                        classModel: cls,
                        db: db),
                  ] else if (user.canMentor || user.isAdmin)
                    Row(
                      children: [
                        const Icon(Icons.people_outline,
                            size: 13, color: AppTheme.textHint),
                        const SizedBox(width: 4),
                        Text('${cls.enrolledUids.length} students',
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textSecondary)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.navy.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(cls.gradingMode == 'percent' ? '% grades' : 'Complete/Incomplete',
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.textSecondary)),
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
}

// ── Progress bar widget (fetches real submission ratio) ───────────────────────
class _ProgressBar extends StatelessWidget {
  final String classId;
  final String studentUid;
  final FirebaseFirestore db;
  final Color color;
  const _ProgressBar({
    required this.classId,
    required this.studentUid,
    required this.db,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<double>(
      future: _calcProgress(),
      builder: (ctx, snap) {
        final pct = snap.data ?? 0.0;
        final barColor = pct >= 0.95
            ? AppTheme.optionalGreen
            : pct >= 0.90
                ? AppTheme.warning
                : AppTheme.error;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Progress',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
                const Spacer(),
                Text('${(pct * 100).round()}%',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: barColor)),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: AppTheme.cardBorder,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
                minHeight: 6,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<double> _calcProgress() async {
    try {
      // Query across all weeks in the class (nested structure)
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
              .where('status',
                  whereIn: ['complete', 'submitted', 'graded'])
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

// ── Grade Indicator (student view – shows weighted grade) ────────────────────
class _GradeIndicator extends StatelessWidget {
  final String classId;
  final String studentUid;
  final ClassModel classModel;
  final FirebaseFirestore db;
  const _GradeIndicator({
    required this.classId,
    required this.studentUid,
    required this.classModel,
    required this.db,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<double?>(
      future: _calcGrade(),
      builder: (ctx, snap) {
        if (!snap.hasData || snap.data == null) return const SizedBox.shrink();
        final grade = snap.data!;
        final cls = classModel;
        final letter = cls.gradebookSimple ? null : cls.letterGrade(grade);
        final color = grade >= 90
            ? AppTheme.optionalGreen
            : grade >= 70
                ? AppTheme.warning
                : AppTheme.error;
        return Row(children: [
          Icon(Icons.star_rounded, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            letter != null
                ? '$letter · ${grade.toStringAsFixed(0)}%'
                : '${grade.toStringAsFixed(0)}%',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color),
          ),
          const SizedBox(width: 4),
          Text('current grade',
              style: const TextStyle(fontSize: 10, color: AppTheme.textHint)),
        ]);
      },
    );
  }

  Future<double?> _calcGrade() async {
    try {
      final weeksSnap = await db
          .collection('classes')
          .doc(classId)
          .collection('weeks')
          .where('isBreak', isEqualTo: false)
          .get();

      double hwTotal = 0; int hwCount = 0;
      double quizTotal = 0; int quizCount = 0;
      double testTotal = 0; int testCount = 0;

      for (final weekDoc in weeksSnap.docs) {
        final hwSnap = await db
            .collection('classes')
            .doc(classId)
            .collection('weeks')
            .doc(weekDoc.id)
            .collection('homework')
            .where('isHidden', isEqualTo: false)
            .get();
        for (final hwDoc in hwSnap.docs) {
          final data = hwDoc.data();
          final itemType = data['itemType'] as String? ?? 'hw';
          if (itemType == 'content') continue;
          final gradingMode = data['gradingMode'] as String? ?? 'complete';
          final maxPoints = (data['maxPoints'] as num?)?.toDouble();

          final subSnap = await db
              .collection('classes')
              .doc(classId)
              .collection('weeks')
              .doc(weekDoc.id)
              .collection('homework')
              .doc(hwDoc.id)
              .collection('submissions')
              .where('studentUid', isEqualTo: studentUid)
              .limit(1)
              .get();
          if (subSnap.docs.isEmpty) continue;
          final sub = subSnap.docs.first.data();
          final status = sub['status'] as String? ?? 'incomplete';
          final grade = (sub['grade'] as num?)?.toDouble();

          double pct;
          if (status == 'graded' && gradingMode == 'percent' && grade != null) {
            pct = maxPoints != null && maxPoints > 0
                ? (grade / maxPoints) * 100
                : grade;
          } else if (status == 'submitted' || status == 'graded' || status == 'complete') {
            pct = 100;
          } else {
            continue;
          }

          if (itemType == 'quiz') {
            quizTotal += pct; quizCount++;
          } else if (itemType == 'test') {
            testTotal += pct; testCount++;
          } else {
            hwTotal += pct; hwCount++;
          }
        }
      }

      if (hwCount == 0 && quizCount == 0 && testCount == 0) return null;

      final cls = classModel;
      double totalWeight = 0, totalScore = 0;
      if (hwCount > 0) {
        totalWeight += cls.weightHw;
        totalScore += (hwTotal / hwCount) * cls.weightHw;
      }
      if (quizCount > 0) {
        totalWeight += cls.weightQuiz;
        totalScore += (quizTotal / quizCount) * cls.weightQuiz;
      }
      if (testCount > 0) {
        totalWeight += cls.weightTest;
        totalScore += (testTotal / testCount) * cls.weightTest;
      }
      return totalWeight > 0 ? totalScore / totalWeight : null;
    } catch (_) {
      return null;
    }
  }
}

// ── Mentor names ──────────────────────────────────────────────────────────────
class _MentorNames extends StatelessWidget {
  final List<String> mentorUids;
  final FirebaseFirestore db;
  const _MentorNames({required this.mentorUids, required this.db});

  @override
  Widget build(BuildContext context) {
    if (mentorUids.isEmpty) {
      return const Text('No mentor assigned',
          style: TextStyle(fontSize: 11, color: AppTheme.textHint));
    }
    return FutureBuilder<List<String>>(
      future: _fetchNames(),
      builder: (ctx, snap) {
        final names = snap.data ?? [];
        return Row(
          children: [
            const Icon(Icons.person_outline, size: 13, color: AppTheme.textHint),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                names.isEmpty ? 'Loading…' : names.join(', '),
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<List<String>> _fetchNames() async {
    final docs = await Future.wait(
        mentorUids.take(3).map((uid) => db.collection('users').doc(uid).get()));
    return docs
        .where((d) => d.exists)
        .map((d) => d.data()?['displayName'] as String? ?? '')
        .where((n) => n.isNotEmpty)
        .toList();
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyClasses extends StatelessWidget {
  final bool canAdd;
  const _EmptyClasses({required this.canAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.menu_book_outlined, size: 64, color: AppTheme.textHint),
          const SizedBox(height: 16),
          const Text('No classes yet',
              style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            canAdd
                ? 'Tap + Add Class to create your first class'
                : 'You haven\'t been enrolled in any classes yet',
            style: const TextStyle(color: AppTheme.textHint, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
