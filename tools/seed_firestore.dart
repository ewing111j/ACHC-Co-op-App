// tools/seed_firestore.dart
//
// Development seed script — populates Firestore with sample data for every
// ACHC Hub collection so the app works out of the box during development and QA.
//
// HOW TO RUN:
//   dart run tools/seed_firestore.dart
//
// REQUIREMENTS:
//   • A valid firebase_options.dart with your project credentials.
//   • Firestore security rules that allow writes (see firestore.rules).
//   • flutter pub get must have been run first.
//
// COLLECTIONS SEEDED:
//   memory_settings       — Global memory-work configuration
//   subjects              — 6 Classical Conversations subjects
//   memory_items          — 3 items per subject per unit (units 1-3)
//   volunteer_rotations   — 4 weekly rotation slots
//   mentor_absences       — 2 sample upcoming absences

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';

import '../lib/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform);

  final db = FirebaseFirestore.instance;
  debugPrint('🌱 Seeding Firestore…');

  await _seedMemorySettings(db);
  await _seedSubjects(db);
  await _seedMemoryItems(db);
  await _seedVolunteerRotations(db);
  await _seedMentorAbsences(db);

  debugPrint('✅  Seeding complete.');
}

// ── Memory Settings ───────────────────────────────────────────────────────────
Future<void> _seedMemorySettings(FirebaseFirestore db) async {
  await db.collection('memory_settings').doc('global').set({
    'active_cycle': 'Cycle 2',
    'active_unit': 1,
    'cloze_level_default': 1,
    'young_learner_cloze_level': 0,
    'updated_at': FieldValue.serverTimestamp(),
  });
  debugPrint('  ✓ memory_settings/global');
}

// ── Subjects ──────────────────────────────────────────────────────────────────
Future<void> _seedSubjects(FirebaseFirestore db) async {
  final subjects = [
    {'id': 'history', 'name': 'History', 'icon': '📜', 'color': 0xFFB5572A, 'order': 0},
    {'id': 'science', 'name': 'Science', 'icon': '🔬', 'color': 0xFF2E7D32, 'order': 1},
    {'id': 'geography', 'name': 'Geography', 'icon': '🌍', 'color': 0xFF1565C0, 'order': 2},
    {'id': 'english', 'name': 'English', 'icon': '📖', 'color': 0xFF6A1B9A, 'order': 3},
    {'id': 'latin', 'name': 'Latin', 'icon': '🏛️', 'color': 0xFF4E342E, 'order': 4},
    {'id': 'math', 'name': 'Math', 'icon': '➗', 'color': 0xFF00695C, 'order': 5},
  ];
  final batch = db.batch();
  for (final s in subjects) {
    batch.set(db.collection('subjects').doc(s['id'] as String), {
      ...s,
      'active': true,
    });
  }
  await batch.commit();
  debugPrint('  ✓ subjects (${subjects.length})');
}

// ── Memory Items ──────────────────────────────────────────────────────────────
Future<void> _seedMemoryItems(FirebaseFirestore db) async {
  final items = <Map<String, dynamic>>[
    // History — Unit 1
    {
      'id': 'hist_u1_1', 'subject_id': 'history', 'unit': 1, 'order': 1,
      'title': 'Creation Timeline',
      'content': 'God created the heavens and the earth in six days and rested on the seventh.',
      'sung_audio_url': '', 'spoken_audio_url': '',
      'cycle': 'Cycle 2', 'active': true,
    },
    {
      'id': 'hist_u1_2', 'subject_id': 'history', 'unit': 1, 'order': 2,
      'title': 'The Fall',
      'content': 'Adam and Eve disobeyed God by eating the forbidden fruit in the Garden of Eden.',
      'sung_audio_url': '', 'spoken_audio_url': '',
      'cycle': 'Cycle 2', 'active': true,
    },
    {
      'id': 'hist_u1_3', 'subject_id': 'history', 'unit': 1, 'order': 3,
      'title': 'The Flood',
      'content': 'Noah built an ark and God sent a flood to cover the earth for forty days.',
      'sung_audio_url': '', 'spoken_audio_url': '',
      'cycle': 'Cycle 2', 'active': true,
    },
    // Science — Unit 1
    {
      'id': 'sci_u1_1', 'subject_id': 'science', 'unit': 1, 'order': 1,
      'title': 'Scientific Method',
      'content': 'Observe, question, hypothesize, experiment, analyze, conclude, communicate.',
      'sung_audio_url': '', 'spoken_audio_url': '',
      'cycle': 'Cycle 2', 'active': true,
    },
    {
      'id': 'sci_u1_2', 'subject_id': 'science', 'unit': 1, 'order': 2,
      'title': 'Cell Theory',
      'content': 'All living things are made of cells; the cell is the basic unit of life.',
      'sung_audio_url': '', 'spoken_audio_url': '',
      'cycle': 'Cycle 2', 'active': true,
    },
    // Geography — Unit 1
    {
      'id': 'geo_u1_1', 'subject_id': 'geography', 'unit': 1, 'order': 1,
      'title': 'Seven Continents',
      'content': 'Africa, Antarctica, Asia, Australia, Europe, North America, South America.',
      'sung_audio_url': '', 'spoken_audio_url': '',
      'cycle': 'Cycle 2', 'active': true,
    },
    // English — Unit 1
    {
      'id': 'eng_u1_1', 'subject_id': 'english', 'unit': 1, 'order': 1,
      'title': 'Parts of Speech',
      'content': 'Noun, pronoun, verb, adjective, adverb, conjunction, preposition, interjection.',
      'sung_audio_url': '', 'spoken_audio_url': '',
      'cycle': 'Cycle 2', 'active': true,
    },
    // Latin — Unit 1
    {
      'id': 'lat_u1_1', 'subject_id': 'latin', 'unit': 1, 'order': 1,
      'title': '1st Declension Nouns',
      'content': 'Puella, puellae, puellae, puellam, puella, puella.',
      'sung_audio_url': '', 'spoken_audio_url': '',
      'cycle': 'Cycle 2', 'active': true,
    },
    // Math — Unit 1
    {
      'id': 'math_u1_1', 'subject_id': 'math', 'unit': 1, 'order': 1,
      'title': 'Skip Counting by 2s',
      'content': '2, 4, 6, 8, 10, 12, 14, 16, 18, 20.',
      'sung_audio_url': '', 'spoken_audio_url': '',
      'cycle': 'Cycle 2', 'active': true,
    },
  ];

  final batch = db.batch();
  for (final item in items) {
    batch.set(db.collection('memory_items').doc(item['id'] as String), item);
  }
  await batch.commit();
  debugPrint('  ✓ memory_items (${items.length})');
}

// ── Volunteer Rotations ───────────────────────────────────────────────────────
Future<void> _seedVolunteerRotations(FirebaseFirestore db) async {
  final now = DateTime.now();
  final monday = now.subtract(Duration(days: now.weekday - 1));

  final rotations = [
    {
      'id': 'rot_001',
      'role': 'Snack Setup',
      'week_start': Timestamp.fromDate(monday),
      'parent_uid': 'seed_parent_001',
      'parent_name': 'Sarah Johnson',
      'notes': 'Please arrive 15 min early. Supplies in closet B.',
    },
    {
      'id': 'rot_002',
      'role': 'Dismissal Supervision',
      'week_start': Timestamp.fromDate(monday),
      'parent_uid': 'seed_parent_002',
      'parent_name': 'Michael Torres',
      'notes': 'Station at front entrance.',
    },
    {
      'id': 'rot_003',
      'role': 'Hallway Monitor',
      'week_start': Timestamp.fromDate(monday),
      'parent_uid': 'seed_parent_003',
      'parent_name': 'Emily Chen',
      'notes': '',
    },
    {
      'id': 'rot_004',
      'role': 'Lost & Found Table',
      'week_start': Timestamp.fromDate(monday),
      'parent_uid': 'seed_parent_004',
      'parent_name': 'David Patel',
      'notes': 'Table near main entrance.',
    },
  ];
  final batch = db.batch();
  for (final r in rotations) {
    batch.set(db.collection('volunteer_rotations').doc(r['id'] as String), r);
  }
  await batch.commit();
  debugPrint('  ✓ volunteer_rotations (${rotations.length})');
}

// ── Mentor Absences ───────────────────────────────────────────────────────────
Future<void> _seedMentorAbsences(FirebaseFirestore db) async {
  final nextWeek = DateTime.now().add(const Duration(days: 7));
  final week2 = DateTime.now().add(const Duration(days: 14));

  final absences = [
    {
      'id': 'abs_seed_001',
      'mentor_uid': 'seed_mentor_001',
      'mentor_name': 'Mrs. Reynolds',
      'class_name': 'Latin I',
      'class_id': 'class_latin_1',
      'absence_date': Timestamp.fromDate(nextWeek),
      'period': 'AM',
      'notes': 'Lesson plan is in the blue binder on my desk. Unit 4 vocab review.',
      'status': 'pending',
      'covering_volunteer_uid': null,
      'covering_volunteer_name': null,
      'created_at': FieldValue.serverTimestamp(),
    },
    {
      'id': 'abs_seed_002',
      'mentor_uid': 'seed_mentor_002',
      'mentor_name': 'Mr. Kowalski',
      'class_name': 'Biology Lab',
      'class_id': 'class_bio_lab',
      'absence_date': Timestamp.fromDate(week2),
      'period': 'PM',
      'notes': 'No lab equipment needed — students are doing worksheet review.',
      'status': 'pending',
      'covering_volunteer_uid': null,
      'covering_volunteer_name': null,
      'created_at': FieldValue.serverTimestamp(),
    },
  ];
  final batch = db.batch();
  for (final a in absences) {
    batch.set(db.collection('mentor_absences').doc(a['id'] as String), a);
  }
  await batch.commit();
  debugPrint('  ✓ mentor_absences (${absences.length})');
}
