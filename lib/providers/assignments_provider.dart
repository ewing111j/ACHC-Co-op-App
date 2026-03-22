// lib/providers/assignments_provider.dart
// Provider-based state management for assignments with Hive offline caching.
// Also merges class homework into the feed for students.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/assignment_model.dart';

/// Box name used for Hive offline cache.
const _kAssignmentsBox = 'assignments_cache';

class AssignmentsProvider extends ChangeNotifier {
  // ── State ────────────────────────────────────────────────────────────────
  List<AssignmentModel> _familyAssignments = [];
  List<AssignmentModel> _classHomework = [];
  bool _isLoading = false;
  String? _error;
  String? _familyId;
  String? _viewUid;

  /// Combined list: family assignments + class homework (deduped by id)
  List<AssignmentModel> get assignments {
    final ids = <String>{};
    final combined = <AssignmentModel>[];
    for (final a in [..._familyAssignments, ..._classHomework]) {
      if (ids.add(a.id)) combined.add(a);
    }
    combined.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return combined;
  }

  bool get isLoading => _isLoading;
  String? get error => _error;

  StreamSubscription<QuerySnapshot>? _sub;
  StreamSubscription<QuerySnapshot>? _classSub;
  late Box<String> _box;
  bool _hiveReady = false;

  // ── Hive init ────────────────────────────────────────────────────────────
  Future<void> initHive() async {
    if (_hiveReady) return;
    try {
      _box = await Hive.openBox<String>(_kAssignmentsBox);
      _hiveReady = true;
    } catch (e) {
      // Hive unavailable – degrade gracefully; live Firestore stream still works.
      debugPrint('[AssignmentsProvider] Hive init failed: $e');
    }
  }

  // ── Load (subscribe to Firestore + hydrate from cache on first frame) ────
  Future<void> load(String familyId, String? viewUid) async {
    if (_familyId == familyId && _viewUid == viewUid) return; // no change
    _familyId = familyId;
    _viewUid = viewUid;

    // Cancel any existing subscriptions.
    await _sub?.cancel();
    await _classSub?.cancel();
    _sub = null;
    _classSub = null;

    _setLoading(true);

    // Hydrate from cache immediately so the UI has something to show.
    _loadFromCache(familyId);

    // Subscribe to live Firestore stream (family/parent-created assignments).
    _sub = FirebaseFirestore.instance
        .collection('assignments')
        .where('familyId', isEqualTo: familyId)
        .snapshots()
        .listen(
          (snap) {
            _familyAssignments = snap.docs
                .map((d) => AssignmentModel.fromMap(d.data(), d.id))
                .toList();
            _error = null;
            _saveToCache(familyId, assignments);
            _setLoading(false);
          },
          onError: (e) {
            _error = 'Could not load assignments: $e';
            _setLoading(false);
          },
        );

    // If this is a student, also listen for class homework assigned to them.
    if (viewUid != null) {
      _loadClassHomeworkForStudent(viewUid);
    }
  }

  /// Load homework from classes the student is enrolled in.
  Future<void> _loadClassHomeworkForStudent(String studentUid) async {
    try {
      final db = FirebaseFirestore.instance;
      // Get all classes the student is enrolled in
      final classesSnap = await db
          .collection('classes')
          .where('enrolledUids', arrayContains: studentUid)
          .get();
      if (classesSnap.docs.isEmpty) return;

      final List<AssignmentModel> hwList = [];

      for (final classDoc in classesSnap.docs) {
        final classId = classDoc.id;
        final className = classDoc.data()['name'] as String? ?? 'Class';

        // Fetch all weeks
        final weeksSnap =
            await db.collection('classes').doc(classId).collection('weeks').get();

        for (final weekDoc in weeksSnap.docs) {
          final weekId = weekDoc.id;
          // Fetch homework for this week
          final hwSnap = await db
              .collection('classes')
              .doc(classId)
              .collection('weeks')
              .doc(weekId)
              .collection('homework')
              .get();

          for (final hwDoc in hwSnap.docs) {
            final data = hwDoc.data();
            if (data['hidden'] == true) continue; // skip hidden homework

            // Check if student has submitted
            AssignmentStatus status = AssignmentStatus.pending;
            try {
              final subSnap = await db
                  .collection('classes')
                  .doc(classId)
                  .collection('weeks')
                  .doc(weekId)
                  .collection('homework')
                  .doc(hwDoc.id)
                  .collection('submissions')
                  .where('studentUid', isEqualTo: studentUid)
                  .limit(1)
                  .get();
              if (subSnap.docs.isNotEmpty) {
                final subStatus =
                    subSnap.docs.first.data()['status'] as String? ?? 'pending';
                status = AssignmentModel.statusFromString(subStatus);
              }
            } catch (_) {}

            final dueDate = data['dueDate'] != null
                ? DateTime.fromMillisecondsSinceEpoch(
                    (data['dueDate'] as dynamic).millisecondsSinceEpoch)
                : DateTime.now().add(const Duration(days: 7));

            hwList.add(AssignmentModel(
              id: 'class_${classId}_${hwDoc.id}',
              title: data['title'] as String? ?? 'Homework',
              description: data['description'] as String? ?? '',
              courseName: className,
              courseId: classId,
              dueDate: dueDate,
              status: status,
              grade: null,
              fromMoodle: false,
              isOptional: false,
              familyId: '',
              createdAt: data['createdAt'] != null
                  ? DateTime.fromMillisecondsSinceEpoch(
                      (data['createdAt'] as dynamic).millisecondsSinceEpoch)
                  : DateTime.now(),
              fromClass: true,
              classId: classId,
              weekId: weekId,
              homeworkId: hwDoc.id,
            ));
          }
        }
      }

      _classHomework = hwList;
      notifyListeners();
    } catch (e) {
      debugPrint('[AssignmentsProvider] Class homework load failed: $e');
    }
  }

  // ── Toggle completion in place ───────────────────────────────────────────
  Future<void> toggleStatus(String id, AssignmentStatus current) async {
    final newStatus =
        (current == AssignmentStatus.pending ||
                current == AssignmentStatus.overdue)
            ? AssignmentStatus.submitted
            : AssignmentStatus.pending;

    // Optimistic local update (family assignments only; class hw handled via dashboard).
    final idx = _familyAssignments.indexWhere((a) => a.id == id);
    if (idx != -1) {
      _familyAssignments[idx] = _familyAssignments[idx].copyWithStatus(newStatus);
      notifyListeners();
    }

    // Persist to Firestore.
    try {
      await FirebaseFirestore.instance
          .collection('assignments')
          .doc(id)
          .update({'status': newStatus.name});
    } catch (e) {
      // Roll back optimistic update on failure.
      if (idx != -1) {
        _familyAssignments[idx] = _familyAssignments[idx].copyWithStatus(current);
        notifyListeners();
      }
      rethrow;
    }
  }

  // ── Cleanup ──────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _sub?.cancel();
    _classSub?.cancel();
    super.dispose();
  }

  // ── Private helpers ──────────────────────────────────────────────────────
  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void _loadFromCache(String familyId) {
    if (!_hiveReady) return;
    try {
      final raw = _box.get('assignments_$familyId');
      if (raw == null) return;
      final decoded = json.decode(raw) as List<dynamic>;
      _familyAssignments = decoded
          .map((m) => AssignmentModel.fromMap(m as Map<String, dynamic>,
              m['id'] as String? ?? ''))
          .where((a) => !a.fromClass) // cache only family assignments
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('[AssignmentsProvider] Cache read failed: $e');
    }
  }

  void _saveToCache(String familyId, List<AssignmentModel> list) {
    if (!_hiveReady) return;
    try {
      // Only cache family assignments (class hw is re-fetched on load)
      final filtered = list.where((a) => !a.fromClass).toList();
      final encoded = json.encode(filtered.map((a) => a.toCacheMap()).toList());
      _box.put('assignments_$familyId', encoded);
    } catch (e) {
      debugPrint('[AssignmentsProvider] Cache write failed: $e');
    }
  }
}

// ── Minimal copyWith for optimistic rollback ─────────────────────────────────
extension _AssignmentStatusCopy on AssignmentModel {
  AssignmentModel copyWithStatus(AssignmentStatus s) => AssignmentModel(
        id: id,
        title: title,
        description: description,
        courseName: courseName,
        courseId: courseId,
        dueDate: dueDate,
        status: s,
        grade: grade,
        maxGrade: maxGrade,
        submissionUrl: submissionUrl,
        fromMoodle: fromMoodle,
        isOptional: isOptional,
        assignedTo: assignedTo,
        familyId: familyId,
        createdAt: createdAt,
        seriesId: seriesId,
        fromClass: fromClass,
        classId: classId,
        weekId: weekId,
        homeworkId: homeworkId,
      );
}
