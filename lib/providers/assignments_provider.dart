// lib/providers/assignments_provider.dart
// Provider-based state management for assignments with Hive offline caching.
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
  List<AssignmentModel> _assignments = [];
  bool _isLoading = false;
  String? _error;
  String? _familyId;
  String? _viewUid;

  List<AssignmentModel> get assignments => _assignments;
  bool get isLoading => _isLoading;
  String? get error => _error;

  StreamSubscription<QuerySnapshot>? _sub;
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

    // Cancel any existing subscription.
    await _sub?.cancel();
    _sub = null;

    _setLoading(true);

    // Hydrate from cache immediately so the UI has something to show.
    _loadFromCache(familyId);

    // Subscribe to live Firestore stream.
    _sub = FirebaseFirestore.instance
        .collection('assignments')
        .where('familyId', isEqualTo: familyId)
        .snapshots()
        .listen(
          (snap) {
            final list = snap.docs
                .map((d) =>
                    AssignmentModel.fromMap(d.data(), d.id))
                .toList()
              ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
            _assignments = list;
            _error = null;
            _saveToCache(familyId, list);
            _setLoading(false);
          },
          onError: (e) {
            _error = 'Could not load assignments: $e';
            _setLoading(false);
          },
        );
  }

  // ── Toggle completion in place ───────────────────────────────────────────
  Future<void> toggleStatus(String id, AssignmentStatus current) async {
    final newStatus =
        (current == AssignmentStatus.pending ||
                current == AssignmentStatus.overdue)
            ? AssignmentStatus.submitted
            : AssignmentStatus.pending;

    // Optimistic local update.
    final idx = _assignments.indexWhere((a) => a.id == id);
    if (idx != -1) {
      final old = _assignments[idx];
      _assignments[idx] = AssignmentModel(
        id: old.id,
        title: old.title,
        description: old.description,
        courseName: old.courseName,
        courseId: old.courseId,
        dueDate: old.dueDate,
        status: newStatus,
        grade: old.grade,
        maxGrade: old.maxGrade,
        submissionUrl: old.submissionUrl,
        fromMoodle: old.fromMoodle,
        isOptional: old.isOptional,
        assignedTo: old.assignedTo,
        familyId: old.familyId,
        createdAt: old.createdAt,
        seriesId: old.seriesId,
      );
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
        _assignments[idx] = _assignments[idx].copyWithStatus(current);
        notifyListeners();
      }
      rethrow;
    }
  }

  // ── Cleanup ──────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _sub?.cancel();
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
      _assignments = decoded
          .map((m) => AssignmentModel.fromMap(m as Map<String, dynamic>,
              m['id'] as String? ?? ''))
          .toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
      notifyListeners();
    } catch (e) {
      debugPrint('[AssignmentsProvider] Cache read failed: $e');
    }
  }

  void _saveToCache(String familyId, List<AssignmentModel> list) {
    if (!_hiveReady) return;
    try {
      final encoded = json.encode(list.map((a) => a.toCacheMap()).toList());
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
      );
}
