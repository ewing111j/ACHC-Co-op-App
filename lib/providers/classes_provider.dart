// lib/providers/classes_provider.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/class_models.dart';
import '../models/user_model.dart';

class ClassesProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const _hiveBoxName = 'classes_cache';
  Box? _box;

  List<ClassModel> _classes = [];
  List<ClassModel> get classes => _classes;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  // ── Init Hive ──────────────────────────────────────────────────────────────
  Future<void> init() async {
    try {
      _box = await Hive.openBox(_hiveBoxName);
      _loadFromCache();
    } catch (e) {
      debugPrint('ClassesProvider.init error: $e');
    }
  }

  void _loadFromCache() {
    try {
      final raw = _box?.get('classes_list') as String?;
      if (raw == null) return;
      final list = jsonDecode(raw) as List<dynamic>;
      _classes = list
          .map((m) => ClassModel.fromCacheMap(m as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('ClassesProvider._loadFromCache error: $e');
    }
  }

  Future<void> _saveToCache(List<ClassModel> list) async {
    try {
      await _box?.put(
          'classes_list', jsonEncode(list.map((c) => c.toCacheMap()).toList()));
    } catch (e) {
      debugPrint('ClassesProvider._saveToCache error: $e');
    }
  }

  // ── Load classes for a user ────────────────────────────────────────────────
  Future<void> loadForUser(UserModel user) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      Query query = _db.collection('classes').where('isArchived', isEqualTo: false);

      // Students/parents see only enrolled classes; mentors/admins see all
      if (user.isStudent) {
        query = query.where('enrolledUids', arrayContains: user.uid);
      } else if (user.isParent && !user.canMentor && !user.isAdmin) {
        // Parent sees classes their kids are enrolled in – we load all and filter
        // (simple approach; for large sets use Cloud Function)
        query = _db.collection('classes').where('isArchived', isEqualTo: false);
      }

      final snap = await query.get();
      final list = snap.docs
          .map((d) => ClassModel.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();

      // Sort by name
      list.sort((a, b) => a.name.compareTo(b.name));
      _classes = list;
      _loading = false;
      _error = null;
      notifyListeners();
      await _saveToCache(list);
    } catch (e) {
      _loading = false;
      _error = 'Failed to load classes: $e';
      notifyListeners();
    }
  }

  // ── Add a class ────────────────────────────────────────────────────────────
  Future<void> addClass(ClassModel cls) async {
    try {
      final docRef = await _db.collection('classes').add(cls.toMap());
      final newCls = ClassModel.fromMap(cls.toMap(), docRef.id);
      _classes = [..._classes, newCls];
      _classes.sort((a, b) => a.name.compareTo(b.name));
      notifyListeners();
      await _saveToCache(_classes);
    } catch (e) {
      rethrow;
    }
  }

  // ── Update a class ─────────────────────────────────────────────────────────
  Future<void> updateClass(ClassModel cls) async {
    try {
      await _db.collection('classes').doc(cls.id).update(cls.toMap());
      final idx = _classes.indexWhere((c) => c.id == cls.id);
      if (idx >= 0) {
        _classes = List.from(_classes)..[idx] = cls;
        notifyListeners();
        await _saveToCache(_classes);
      }
    } catch (e) {
      rethrow;
    }
  }

  // ── Get a single class by ID ───────────────────────────────────────────────
  ClassModel? getById(String id) {
    try {
      return _classes.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  // ── Enroll / unenroll student ──────────────────────────────────────────────
  Future<void> enrollStudent(String classId, String studentUid) async {
    await _db.collection('classes').doc(classId).update({
      'enrolledUids': FieldValue.arrayUnion([studentUid]),
    });
    _refreshClass(classId);
  }

  Future<void> unenrollStudent(String classId, String studentUid) async {
    await _db.collection('classes').doc(classId).update({
      'enrolledUids': FieldValue.arrayRemove([studentUid]),
    });
    _refreshClass(classId);
  }

  // ── Assign / remove mentor ─────────────────────────────────────────────────
  Future<void> assignMentor(String classId, String mentorUid) async {
    await _db.collection('classes').doc(classId).update({
      'mentorUids': FieldValue.arrayUnion([mentorUid]),
    });
    _refreshClass(classId);
  }

  Future<void> removeMentor(String classId, String mentorUid) async {
    await _db.collection('classes').doc(classId).update({
      'mentorUids': FieldValue.arrayRemove([mentorUid]),
    });
    _refreshClass(classId);
  }

  Future<void> _refreshClass(String classId) async {
    try {
      final doc = await _db.collection('classes').doc(classId).get();
      if (!doc.exists) return;
      final updated =
          ClassModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      final idx = _classes.indexWhere((c) => c.id == classId);
      if (idx >= 0) {
        _classes = List.from(_classes)..[idx] = updated;
      } else {
        _classes = [..._classes, updated];
      }
      notifyListeners();
      await _saveToCache(_classes);
    } catch (_) {}
  }

  // ── Generate week template for new class ──────────────────────────────────
  Future<void> generateWeekTemplate(
      String classId, String schoolYearId) async {
    try {
      // Get school year calendar
      final calSnap = await _db
          .collection('coopCalendar')
          .where('schoolYearId', isEqualTo: schoolYearId)
          .orderBy('weekStart')
          .get();

      final batch = _db.batch();
      for (final doc in calSnap.docs) {
        final data = doc.data();
        final weekRef = _db
            .collection('classes')
            .doc(classId)
            .collection('weeks')
            .doc();
        batch.set(weekRef, {
          'calendarWeekId': doc.id,
          'label': data['label'] as String? ?? '',
          'weekStart': data['weekStart'],
          'weekEnd': data['weekEnd'],
          'weekNumber': data['weekNumber'] ?? 0,
          'isBreak': data['isBreak'] ?? false,
          'isHidden': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      debugPrint('generateWeekTemplate error: $e');
    }
  }

  void clear() {
    _classes = [];
    _loading = false;
    _error = null;
    notifyListeners();
  }
}
