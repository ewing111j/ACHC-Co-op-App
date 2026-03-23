import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ClassModeProvider
//
// Governs Mentor Class Mode state. When active:
//  - Font scaling is ~140%
//  - Bottom navigation is hidden
//  - An "Exit Class Mode" overlay button is shown
//  - Enrolled student IDs are cached for WP broadcast
//  - Drill mode is disabled; Class Battle is accessible
// ─────────────────────────────────────────────────────────────────────────────

class ClassModeProvider extends ChangeNotifier {
  final FirebaseFirestore _db;

  ClassModeProvider(this._db);

  bool _isActive = false;
  List<String> _enrolledStudentIds = [];
  String? _currentClassId;

  bool get isActive => _isActive;
  List<String> get enrolledStudentIds => _enrolledStudentIds;
  String? get currentClassId => _currentClassId;

  /// Enter class mode, optionally loading enrolled students for a class.
  Future<void> enterClassMode(UserModel mentor) async {
    _isActive = true;
    _enrolledStudentIds = [];

    // Load enrolled students from the first mentor class
    if (mentor.mentorClassIds.isNotEmpty) {
      _currentClassId = mentor.mentorClassIds.first;
      await _loadEnrolledStudents(_currentClassId!);
    }

    notifyListeners();
  }

  Future<void> _loadEnrolledStudents(String classId) async {
    try {
      final snap = await _db
          .collection('classes')
          .doc(classId)
          .get();

      if (snap.exists && snap.data() != null) {
        final data = snap.data()!;
        _enrolledStudentIds =
            List<String>.from(data['student_uids'] as List? ?? []);
      }
    } catch (_) {
      // Non-fatal — WP broadcast will just skip if empty
    }
  }

  /// Exit class mode and reset all state.
  void exitClassMode() {
    _isActive = false;
    _enrolledStudentIds = [];
    _currentClassId = null;
    notifyListeners();
  }

  /// Broadcast WP to all enrolled students (used on Class Battle victory).
  /// Returns count of students updated.
  Future<int> broadcastWP({required int wp}) async {
    if (_enrolledStudentIds.isEmpty) return 0;

    final batch = _db.batch();
    int count = 0;

    for (final studentId in _enrolledStudentIds) {
      try {
        // Find active lumen_state for this student
        final lumenSnap = await _db
            .collection('lumen_state')
            .where('student_id', isEqualTo: studentId)
            .where('is_active', isEqualTo: true)
            .limit(1)
            .get();

        if (lumenSnap.docs.isNotEmpty) {
          final doc = lumenSnap.docs.first;
          final currentWp = (doc.data()['current_wp'] as int?) ?? 0;
          final totalWp = (doc.data()['total_wp'] as int?) ?? 0;

          batch.update(doc.reference, {
            'current_wp': currentWp + wp,
            'total_wp': totalWp + wp,
          });
          count++;
        }
      } catch (_) {
        // Skip failed student
      }
    }

    await batch.commit();
    return count;
  }
}
