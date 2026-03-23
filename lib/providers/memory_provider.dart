import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/memory/memory_models.dart';
import '../models/user_model.dart';

/// Central state provider for the Memory Work module.
/// Loaded once when the user enters MemoryWorkHomeScreen.
class MemoryProvider extends ChangeNotifier {
  final FirebaseFirestore _db;

  MemoryProvider(this._db);

  // ── State ────────────────────────────────────────────────────────────────
  bool _loading = false;
  String? _error;
  MemorySettings _settings = MemorySettings.defaults;
  CycleModel? _activeCycle;
  List<SubjectModel> _subjects = [];
  List<UnitModel> _units = [];

  // Per-student runtime state (loaded when student context set)
  String? _studentId;
  LumenStateModel? _lumenState;
  Map<String, StudentProgressModel> _progressMap = {}; // key = memory_item_id
  List<AchievementModel> _achievements = [];

  // ── Getters ───────────────────────────────────────────────────────────────
  bool get loading => _loading;
  String? get error => _error;
  MemorySettings get settings => _settings;
  CycleModel? get activeCycle => _activeCycle;
  List<SubjectModel> get subjects => _subjects;
  List<UnitModel> get units => _units;
  String get activeCycleId => _settings.activeCycleId;
  int get currentUnit => _settings.currentUnit;
  LumenStateModel? get lumenState => _lumenState;
  List<AchievementModel> get achievements => _achievements;

  UnitModel? get currentUnitModel => _units
      .where((u) => u.unitNumber == _settings.currentUnit && u.cycleId == activeCycleId)
      .firstOrNull;

  StudentProgressModel? progressFor(String memoryItemId) => _progressMap[memoryItemId];

  // ── Load ──────────────────────────────────────────────────────────────────
  Future<void> load({String? studentId}) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Load settings (active cycle + current unit)
      final settingsDoc = await _db.collection('memory_settings').doc('global').get();
      if (settingsDoc.exists && settingsDoc.data() != null) {
        _settings = MemorySettings.fromMap(settingsDoc.data()!);
      }

      // 2. Load active cycle
      final cycleDoc = await _db.collection('cycles').doc(_settings.activeCycleId).get();
      if (cycleDoc.exists && cycleDoc.data() != null) {
        _activeCycle = CycleModel.fromMap(cycleDoc.id, cycleDoc.data()!);
      }

      // 3. Load subjects (sorted)
      final subjectSnap = await _db.collection('subjects').orderBy('sort_order').get();
      _subjects = subjectSnap.docs
          .map((d) => SubjectModel.fromMap(d.id, d.data()))
          .toList();

      // 4. Load units for active cycle
      final unitSnap = await _db
          .collection('units')
          .where('cycle_id', isEqualTo: _settings.activeCycleId)
          .get();
      _units = unitSnap.docs
          .map((d) => UnitModel.fromMap(d.id, d.data()))
          .toList()
        ..sort((a, b) => a.unitNumber.compareTo(b.unitNumber));

      // 5. Load student data if student context provided
      if (studentId != null) {
        await _loadStudentData(studentId);
      }
    } catch (e) {
      _error = 'Failed to load Memory Work: $e';
      if (kDebugMode) debugPrint(_error);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _loadStudentData(String studentId) async {
    _studentId = studentId;

    // Lumen state
    final lumenSnap = await _db
        .collection('lumen_state')
        .where('student_id', isEqualTo: studentId)
        .where('cycle_id', isEqualTo: activeCycleId)
        .where('is_active', isEqualTo: true)
        .limit(1)
        .get();

    if (lumenSnap.docs.isNotEmpty) {
      _lumenState = LumenStateModel.fromMap(lumenSnap.docs.first.id, lumenSnap.docs.first.data());
    } else {
      // Create initial lumen state for this student+cycle
      final newRef = _db.collection('lumen_state').doc();
      final initial = LumenStateModel(
        id: newRef.id,
        studentId: studentId,
        cycleId: activeCycleId,
        lumenLevel: 1,
        totalWp: 0,
        currentWp: 0,
        unlockedItems: [],
        battleWins: 0,
        isActive: true,
        createdAt: DateTime.now(),
      );
      await newRef.set(initial.toMap());
      _lumenState = initial;
    }

    // Progress records for this cycle
    final progressSnap = await _db
        .collection('student_progress')
        .where('student_id', isEqualTo: studentId)
        .where('cycle_id', isEqualTo: activeCycleId)
        .where('is_active_cycle', isEqualTo: true)
        .get();

    _progressMap = {
      for (final d in progressSnap.docs)
        (d.data()['memory_item_id'] as String? ?? d.id):
            StudentProgressModel.fromMap(d.id, d.data()),
    };

    // Achievements
    final achSnap = await _db
        .collection('achievements')
        .where('student_id', isEqualTo: studentId)
        .where('cycle_id', isEqualTo: activeCycleId)
        .where('is_active_cycle', isEqualTo: true)
        .get();

    _achievements = achSnap.docs
        .map((d) => AchievementModel.fromMap(d.id, d.data()))
        .toList();
  }

  /// Load memory items for a specific subject + unit
  Future<List<MemoryItemModel>> loadMemoryItems({
    required String subjectId,
    required int unitNumber,
  }) async {
    // Find the unit document ID
    final unit = _units.firstWhere(
      (u) => u.unitNumber == unitNumber && u.cycleId == activeCycleId,
      orElse: () => UnitModel(
        id: '${activeCycleId}_unit_$unitNumber',
        unitNumber: unitNumber,
        unitType: 'content',
        cycleId: activeCycleId,
        label: 'Unit $unitNumber',
      ),
    );

    final snap = await _db
        .collection('memory_items')
        .where('subject_id', isEqualTo: subjectId)
        .where('unit_id', isEqualTo: unit.id)
        .where('cycle_id', isEqualTo: activeCycleId)
        .get();

    return snap.docs.map((d) => MemoryItemModel.fromMap(d.id, d.data())).toList();
  }

  /// Load ALL memory items for a subject (all units), used in SubjectDetailScreen
  Future<List<MemoryItemModel>> loadAllItemsForSubject(String subjectId) async {
    final snap = await _db
        .collection('memory_items')
        .where('subject_id', isEqualTo: subjectId)
        .where('cycle_id', isEqualTo: activeCycleId)
        .get();

    final items = snap.docs.map((d) => MemoryItemModel.fromMap(d.id, d.data())).toList();

    // Sort by unit number
    final unitNumberMap = {for (final u in _units) u.id: u.unitNumber};
    items.sort((a, b) =>
        (unitNumberMap[a.unitId] ?? 0).compareTo(unitNumberMap[b.unitId] ?? 0));

    return items;
  }

  // ── Progress updates ──────────────────────────────────────────────────────
  Future<void> updateProgress({
    required String memoryItemId,
    required int masteryLevel,
    required int wpEarned,
    required bool sungPlayedFirst,
  }) async {
    if (_studentId == null) return;

    final existing = _progressMap[memoryItemId];
    final now = DateTime.now();

    if (existing != null) {
      final updated = StudentProgressModel(
        id: existing.id,
        studentId: existing.studentId,
        memoryItemId: memoryItemId,
        cycleId: activeCycleId,
        masteryLevel: masteryLevel,
        lastPracticed: now,
        practiceCount: existing.practiceCount + 1,
        wpEarnedTotal: existing.wpEarnedTotal + wpEarned,
        isActiveCycle: true,
        sungPlayedFirst: existing.sungPlayedFirst || sungPlayedFirst,
      );
      await _db.collection('student_progress').doc(existing.id).update(updated.toMap());
      _progressMap[memoryItemId] = updated;
    } else {
      final ref = _db.collection('student_progress').doc();
      final progress = StudentProgressModel(
        id: ref.id,
        studentId: _studentId!,
        memoryItemId: memoryItemId,
        cycleId: activeCycleId,
        masteryLevel: masteryLevel,
        lastPracticed: now,
        practiceCount: 1,
        wpEarnedTotal: wpEarned,
        isActiveCycle: true,
        sungPlayedFirst: sungPlayedFirst,
      );
      await ref.set(progress.toMap());
      _progressMap[memoryItemId] = progress;
    }

    notifyListeners();
  }

  /// Award WP and update lumen state
  Future<LumenStateModel?> awardWP(int wp) async {
    if (_lumenState == null || _studentId == null) return null;

    final newCurrentWp = _lumenState!.currentWp + wp;
    final newTotalWp = _lumenState!.totalWp + wp;

    // Check level-up
    int newLevel = _lumenState!.lumenLevel;
    int adjustedCurrentWp = newCurrentWp;

    while (newLevel < 5 &&
        newLevel < LumenStateModel.levelThresholds.length &&
        adjustedCurrentWp >= LumenStateModel.levelThresholds[newLevel]) {
      newLevel++;
    }

    final updated = _lumenState!.copyWith(
      lumenLevel: newLevel,
      totalWp: newTotalWp,
      currentWp: adjustedCurrentWp,
    );

    await _db.collection('lumen_state').doc(_lumenState!.id).update({
      'current_wp': adjustedCurrentWp,
      'total_wp': newTotalWp,
      'lumen_level': newLevel,
    });

    final didLevelUp = newLevel > _lumenState!.lumenLevel;
    _lumenState = updated;
    notifyListeners();

    return didLevelUp ? updated : null; // return non-null if leveled up
  }

  /// Mark sung audio as played (first time = +2 WP)
  Future<int> recordSungPlayed(String memoryItemId) async {
    final existing = _progressMap[memoryItemId];
    if (existing != null && existing.sungPlayedFirst) return 0;

    // First time = +2 WP
    if (_studentId != null && existing != null) {
      await _db.collection('student_progress').doc(existing.id).update({
        'sung_played_first': true,
      });
      _progressMap[memoryItemId] = StudentProgressModel(
        id: existing.id,
        studentId: existing.studentId,
        memoryItemId: memoryItemId,
        cycleId: existing.cycleId,
        masteryLevel: existing.masteryLevel,
        lastPracticed: existing.lastPracticed,
        practiceCount: existing.practiceCount,
        wpEarnedTotal: existing.wpEarnedTotal,
        isActiveCycle: existing.isActiveCycle,
        sungPlayedFirst: true,
      );
    }
    return 2;
  }

  // ── Admin settings ────────────────────────────────────────────────────────
  Future<void> saveSettings(MemorySettings newSettings) async {
    await _db.collection('memory_settings').doc('global').set(newSettings.toMap());
    _settings = newSettings;
    notifyListeners();
  }

  void refreshStudentData() {
    if (_studentId != null) {
      _loadStudentData(_studentId!).then((_) => notifyListeners());
    }
  }
}
