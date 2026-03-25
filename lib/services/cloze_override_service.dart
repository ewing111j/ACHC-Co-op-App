// lib/services/cloze_override_service.dart
// P2-5: Firestore-backed cloze level overrides set by admins/mentors.
// Collection: cloze_overrides
// Document ID: {classId}_{subjectId}_{unitId}  (unitId may be "all")

import 'package:cloud_firestore/cloud_firestore.dart';

class ClozeOverrideModel {
  final String classId;
  final String subjectId;
  final String unitId; // specific unit number as string, or "all"
  final int level;     // 1–5
  final String setBy;  // uid
  final DateTime setAt;
  final String? note;

  const ClozeOverrideModel({
    required this.classId,
    required this.subjectId,
    required this.unitId,
    required this.level,
    required this.setBy,
    required this.setAt,
    this.note,
  });

  String get docId => '${classId}_${subjectId}_$unitId';

  factory ClozeOverrideModel.fromMap(Map<String, dynamic> m) =>
      ClozeOverrideModel(
        classId: m['class_id'] as String? ?? '',
        subjectId: m['subject_id'] as String? ?? '',
        unitId: m['unit_id'] as String? ?? 'all',
        level: (m['level'] as int?) ?? 1,
        setBy: m['set_by'] as String? ?? '',
        setAt: m['set_at'] is Timestamp
            ? (m['set_at'] as Timestamp).toDate()
            : DateTime.now(),
        note: m['note'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'class_id': classId,
        'subject_id': subjectId,
        'unit_id': unitId,
        'level': level,
        'set_by': setBy,
        'set_at': FieldValue.serverTimestamp(),
        'note': note,
      };
}

class ClozeOverrideService {
  final FirebaseFirestore _db;

  ClozeOverrideService([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('cloze_overrides');

  // ── Read ────────────────────────────────────────────────────────────────────

  /// Returns the effective cloze level for the given class+subject+unit,
  /// or null if no override is set.
  /// Checks unit-specific first, then falls back to subject-wide ("all").
  Future<int?> getOverrideLevel({
    required String classId,
    required String subjectId,
    required int unitNumber,
  }) async {
    try {
      // 1. Unit-specific
      final unitDoc = await _col
          .doc('${classId}_${subjectId}_$unitNumber')
          .get();
      if (unitDoc.exists && unitDoc.data() != null) {
        return unitDoc.data()!['level'] as int?;
      }
      // 2. Subject-wide
      final allDoc = await _col
          .doc('${classId}_${subjectId}_all')
          .get();
      if (allDoc.exists && allDoc.data() != null) {
        return allDoc.data()!['level'] as int?;
      }
    } catch (_) {
      // Non-fatal; fall through
    }
    return null;
  }

  /// Stream all overrides for a given class.
  Stream<List<ClozeOverrideModel>> overridesForClass(String classId) {
    return _col
        .where('class_id', isEqualTo: classId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ClozeOverrideModel.fromMap(d.data()))
            .toList());
  }

  // ── Write ───────────────────────────────────────────────────────────────────

  Future<void> setOverride(ClozeOverrideModel override) async {
    await _col.doc(override.docId).set(override.toMap());
  }

  Future<void> clearOverride({
    required String classId,
    required String subjectId,
    required String unitId,
  }) async {
    await _col.doc('${classId}_${subjectId}_$unitId').delete();
  }

  /// Clear all overrides for a class.
  Future<void> clearAllForClass(String classId) async {
    final snap = await _col.where('class_id', isEqualTo: classId).get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
