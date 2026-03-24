// lib/services/coverage_service.dart
// Firestore operations for the Mentor Absence / Coverage system (P1-2).

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/coverage_models.dart';
import '../models/user_model.dart';

class CoverageService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String _absencesCol = 'mentor_absences';
  static const String _volunteersCol = 'coverage_volunteers';

  // ── Absences ──────────────────────────────────────────────────────────────

  /// Stream of ALL upcoming absences (admin view).
  Stream<List<MentorAbsenceModel>> streamAllAbsences() {
    final now = DateTime.now();
    return _db
        .collection(_absencesCol)
        .where('absence_date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(
                DateTime(now.year, now.month, now.day)))
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => MentorAbsenceModel.fromFirestore(d.data(), d.id))
            .toList()
          ..sort((a, b) => a.absenceDate.compareTo(b.absenceDate)));
  }

  /// Stream of pending/uncovered absences only (volunteer banner).
  Stream<List<MentorAbsenceModel>> streamOpenAbsences() {
    final now = DateTime.now();
    return _db
        .collection(_absencesCol)
        .where('absence_date',
            isGreaterThanOrEqualTo:
                Timestamp.fromDate(DateTime(now.year, now.month, now.day)))
        .where('status', whereIn: [
          AbsenceStatus.pending,
          AbsenceStatus.uncovered,
        ])
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => MentorAbsenceModel.fromFirestore(d.data(), d.id))
            .toList()
          ..sort((a, b) => a.absenceDate.compareTo(b.absenceDate)));
  }

  /// Stream of absences reported by a specific mentor.
  Stream<List<MentorAbsenceModel>> streamMyAbsences(String mentorUid) {
    return _db
        .collection(_absencesCol)
        .where('mentor_uid', isEqualTo: mentorUid)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => MentorAbsenceModel.fromFirestore(d.data(), d.id))
            .toList()
          ..sort((a, b) => b.absenceDate.compareTo(a.absenceDate)));
  }

  /// Report a new absence.
  Future<void> reportAbsence(MentorAbsenceModel absence) async {
    await _db.collection(_absencesCol).doc(absence.id.isEmpty ? null : absence.id).set(
          absence.toFirestore(),
          SetOptions(merge: true),
        );
  }

  /// Update status on an existing absence.
  Future<void> updateAbsenceStatus(
      String absenceId, String status,
      {String? coveringUid, String? coveringName}) async {
    final update = <String, dynamic>{'status': status};
    if (coveringUid != null) update['covering_volunteer_uid'] = coveringUid;
    if (coveringName != null) update['covering_volunteer_name'] = coveringName;
    await _db.collection(_absencesCol).doc(absenceId).update(update);
  }

  /// Cancel / delete an absence (mentor self-cancel).
  Future<void> deleteAbsence(String absenceId) async {
    await _db.collection(_absencesCol).doc(absenceId).delete();
  }

  // ── Volunteers ────────────────────────────────────────────────────────────

  /// Stream of volunteers who offered to cover a specific absence.
  Stream<List<CoverageVolunteerModel>> streamVolunteersForAbsence(
      String absenceId) {
    return _db
        .collection(_volunteersCol)
        .where('absence_id', isEqualTo: absenceId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) =>
                CoverageVolunteerModel.fromFirestore(d.data(), d.id))
            .toList());
  }

  /// Offer to cover an absence.
  Future<void> offerCoverage(
      String absenceId, UserModel volunteer) async {
    final docRef = _db.collection(_volunteersCol).doc();
    final model = CoverageVolunteerModel(
      id: docRef.id,
      absenceId: absenceId,
      volunteerUid: volunteer.uid,
      volunteerName: volunteer.displayName,
      offeredAt: DateTime.now(),
      accepted: false,
    );
    await docRef.set(model.toFirestore());
  }

  /// Accept a volunteer (admin action) — marks their record accepted and
  /// updates the parent absence to "covered".
  Future<void> acceptVolunteer(
      String absenceId, CoverageVolunteerModel volunteer) async {
    final batch = _db.batch();

    // Mark volunteer accepted
    batch.update(
      _db.collection(_volunteersCol).doc(volunteer.id),
      {'accepted': true},
    );

    // Mark absence covered
    batch.update(
      _db.collection(_absencesCol).doc(absenceId),
      {
        'status': AbsenceStatus.covered,
        'covering_volunteer_uid': volunteer.volunteerUid,
        'covering_volunteer_name': volunteer.volunteerName,
      },
    );

    await batch.commit();
  }
}
