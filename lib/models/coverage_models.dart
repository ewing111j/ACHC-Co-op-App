// lib/models/coverage_models.dart
// Data models for the Mentor Absence / Coverage system (P1-2).

import 'package:cloud_firestore/cloud_firestore.dart';

// ── Absence status constants ──────────────────────────────────────────────────
class AbsenceStatus {
  static const String pending = 'pending';
  static const String covered = 'covered';
  static const String uncovered = 'uncovered';
}

// ── MentorAbsence ─────────────────────────────────────────────────────────────
class MentorAbsenceModel {
  final String id;
  final String mentorUid;
  final String mentorName;
  final String className;
  final String classId;
  final DateTime absenceDate;
  final String period; // e.g. "AM" | "PM" | "All Day"
  final String notes;
  final String status; // pending | covered | uncovered
  final String? coveringVolunteerUid;
  final String? coveringVolunteerName;
  final DateTime createdAt;

  const MentorAbsenceModel({
    required this.id,
    required this.mentorUid,
    required this.mentorName,
    required this.className,
    required this.classId,
    required this.absenceDate,
    required this.period,
    required this.notes,
    required this.status,
    this.coveringVolunteerUid,
    this.coveringVolunteerName,
    required this.createdAt,
  });

  factory MentorAbsenceModel.fromFirestore(
      Map<String, dynamic> data, String docId) {
    return MentorAbsenceModel(
      id: docId,
      mentorUid: data['mentor_uid'] as String? ?? '',
      mentorName: data['mentor_name'] as String? ?? '',
      className: data['class_name'] as String? ?? '',
      classId: data['class_id'] as String? ?? '',
      absenceDate: (data['absence_date'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      period: data['period'] as String? ?? 'All Day',
      notes: data['notes'] as String? ?? '',
      status: data['status'] as String? ?? AbsenceStatus.pending,
      coveringVolunteerUid: data['covering_volunteer_uid'] as String?,
      coveringVolunteerName: data['covering_volunteer_name'] as String?,
      createdAt:
          (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'mentor_uid': mentorUid,
        'mentor_name': mentorName,
        'class_name': className,
        'class_id': classId,
        'absence_date': Timestamp.fromDate(absenceDate),
        'period': period,
        'notes': notes,
        'status': status,
        'covering_volunteer_uid': coveringVolunteerUid,
        'covering_volunteer_name': coveringVolunteerName,
        'created_at': FieldValue.serverTimestamp(),
      };

  MentorAbsenceModel copyWith({
    String? status,
    String? coveringVolunteerUid,
    String? coveringVolunteerName,
  }) =>
      MentorAbsenceModel(
        id: id,
        mentorUid: mentorUid,
        mentorName: mentorName,
        className: className,
        classId: classId,
        absenceDate: absenceDate,
        period: period,
        notes: notes,
        status: status ?? this.status,
        coveringVolunteerUid:
            coveringVolunteerUid ?? this.coveringVolunteerUid,
        coveringVolunteerName:
            coveringVolunteerName ?? this.coveringVolunteerName,
        createdAt: createdAt,
      );
}

// ── CoverageVolunteer ─────────────────────────────────────────────────────────
class CoverageVolunteerModel {
  final String id;
  final String absenceId;
  final String volunteerUid;
  final String volunteerName;
  final DateTime offeredAt;
  final bool accepted;

  const CoverageVolunteerModel({
    required this.id,
    required this.absenceId,
    required this.volunteerUid,
    required this.volunteerName,
    required this.offeredAt,
    required this.accepted,
  });

  factory CoverageVolunteerModel.fromFirestore(
      Map<String, dynamic> data, String docId) {
    return CoverageVolunteerModel(
      id: docId,
      absenceId: data['absence_id'] as String? ?? '',
      volunteerUid: data['volunteer_uid'] as String? ?? '',
      volunteerName: data['volunteer_name'] as String? ?? '',
      offeredAt: (data['offered_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      accepted: data['accepted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'absence_id': absenceId,
        'volunteer_uid': volunteerUid,
        'volunteer_name': volunteerName,
        'offered_at': FieldValue.serverTimestamp(),
        'accepted': accepted,
      };
}
