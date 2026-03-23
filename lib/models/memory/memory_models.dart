import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Cycle ────────────────────────────────────────────────────────────────────
class CycleModel {
  final String id;
  final String name;
  final bool isActive;
  final DateTime? activatedAt;

  const CycleModel({
    required this.id,
    required this.name,
    required this.isActive,
    this.activatedAt,
  });

  factory CycleModel.fromMap(String id, Map<String, dynamic> m) => CycleModel(
        id: id,
        name: m['name'] as String? ?? id,
        isActive: m['is_active'] as bool? ?? false,
        activatedAt: m['activated_at'] is Timestamp
            ? (m['activated_at'] as Timestamp).toDate()
            : null,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'is_active': isActive,
        'activated_at': activatedAt != null ? Timestamp.fromDate(activatedAt!) : null,
      };
}

// ─── Subject ──────────────────────────────────────────────────────────────────
class SubjectModel {
  final String id;
  final String name;
  final String icon;
  final String color;
  final String contentType; // A, B, or C
  final int sortOrder;

  const SubjectModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.contentType,
    required this.sortOrder,
  });

  factory SubjectModel.fromMap(String id, Map<String, dynamic> m) => SubjectModel(
        id: id,
        name: m['name'] as String? ?? id,
        icon: m['icon'] as String? ?? 'book',
        color: m['color'] as String? ?? '#1B2A4A',
        contentType: m['content_type'] as String? ?? 'B',
        sortOrder: m['sort_order'] as int? ?? 0,
      );

  /// Soft prompt text for Type B subjects
  String get softPrompt {
    switch (id) {
      case 'history':
        return 'Describe this period of history:';
      case 'scripture':
        return 'Recite this passage:';
      case 'great_words_1':
      case 'great_words_2':
        return 'What do you know about this concept?';
      case 'latin':
        return 'Recite this conjugation or passage:';
      default:
        return '';
    }
  }
}

// ─── Unit ─────────────────────────────────────────────────────────────────────
class UnitModel {
  final String id;
  final int unitNumber;
  final String unitType; // content, review, break
  final String cycleId;
  final String label;

  const UnitModel({
    required this.id,
    required this.unitNumber,
    required this.unitType,
    required this.cycleId,
    required this.label,
  });

  bool get isContent => unitType == 'content';
  bool get isReview => unitType == 'review';
  bool get isBreak => unitType == 'break';

  factory UnitModel.fromMap(String id, Map<String, dynamic> m) => UnitModel(
        id: id,
        unitNumber: m['unit_number'] as int? ?? 0,
        unitType: m['unit_type'] as String? ?? 'content',
        cycleId: m['cycle_id'] as String? ?? '',
        label: m['label'] as String? ?? 'Unit ${m['unit_number']}',
      );
}

// ─── Memory Item ──────────────────────────────────────────────────────────────
class MemoryItemModel {
  final String id;
  final String subjectId;
  final String unitId;
  final String cycleId;
  final String? questionText;
  final String contentText;
  final String contentType; // A, B, or C
  final String? sungAudioUrl;
  final String? spokenAudioUrl;
  final String? timelineFullSongUrl;
  final String? clozeOverrides;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MemoryItemModel({
    required this.id,
    required this.subjectId,
    required this.unitId,
    required this.cycleId,
    this.questionText,
    required this.contentText,
    required this.contentType,
    this.sungAudioUrl,
    this.spokenAudioUrl,
    this.timelineFullSongUrl,
    this.clozeOverrides,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MemoryItemModel.fromMap(String id, Map<String, dynamic> m) {
    DateTime parseTs(dynamic v) {
      if (v is Timestamp) return v.toDate();
      return DateTime.now();
    }

    return MemoryItemModel(
      id: id,
      subjectId: m['subject_id'] as String? ?? '',
      unitId: m['unit_id'] as String? ?? '',
      cycleId: m['cycle_id'] as String? ?? '',
      questionText: m['question_text'] as String?,
      contentText: m['content_text'] as String? ?? '',
      contentType: m['content_type'] as String? ?? 'B',
      sungAudioUrl: m['sung_audio_url'] as String?,
      spokenAudioUrl: m['spoken_audio_url'] as String?,
      timelineFullSongUrl: m['timeline_full_song_url'] as String?,
      clozeOverrides: m['cloze_overrides'] as String?,
      createdAt: parseTs(m['created_at']),
      updatedAt: parseTs(m['updated_at']),
    );
  }

  Map<String, dynamic> toMap() => {
        'subject_id': subjectId,
        'unit_id': unitId,
        'cycle_id': cycleId,
        'question_text': questionText,
        'content_text': contentText,
        'content_type': contentType,
        'sung_audio_url': sungAudioUrl,
        'spoken_audio_url': spokenAudioUrl,
        'timeline_full_song_url': timelineFullSongUrl,
        'cloze_overrides': clozeOverrides,
        'created_at': Timestamp.fromDate(createdAt),
        'updated_at': Timestamp.fromDate(updatedAt),
      };
}

// ─── Student Progress ─────────────────────────────────────────────────────────
class StudentProgressModel {
  final String id;
  final String studentId;
  final String memoryItemId;
  final String cycleId;
  final int masteryLevel; // 0=unrated, 1=just heard, 2=getting there, 3=got it
  final DateTime? lastPracticed;
  final int sungPlayCount;   // replaces practiceCount — sung audio plays
  final int spokenPlayCount; // spoken audio plays
  final int wpEarnedTotal;
  final bool isActiveCycle;
  final bool sungPlayedFirst;

  const StudentProgressModel({
    required this.id,
    required this.studentId,
    required this.memoryItemId,
    required this.cycleId,
    required this.masteryLevel,
    this.lastPracticed,
    this.sungPlayCount = 0,
    this.spokenPlayCount = 0,
    required this.wpEarnedTotal,
    required this.isActiveCycle,
    required this.sungPlayedFirst,
  });

  /// Backwards-compat total for display (sung + spoken)
  int get practiceCount => sungPlayCount + spokenPlayCount;

  String get masteryLabel {
    switch (masteryLevel) {
      case 1:
        return 'Just Heard It';
      case 2:
        return 'Getting There';
      case 3:
        return 'Got It';
      default:
        return 'Not Rated';
    }
  }

  factory StudentProgressModel.fromMap(String id, Map<String, dynamic> m) {
    DateTime? parseTs(dynamic v) {
      if (v is Timestamp) return v.toDate();
      return null;
    }

    return StudentProgressModel(
      id: id,
      studentId: m['student_id'] as String? ?? '',
      memoryItemId: m['memory_item_id'] as String? ?? '',
      cycleId: m['cycle_id'] as String? ?? '',
      masteryLevel: m['mastery_level'] as int? ?? 0,
      lastPracticed: parseTs(m['last_practiced']),
      sungPlayCount: (m['sung_play_count'] as int?) ??
          (m['practice_count'] as int? ?? 0), // migrate old field
      spokenPlayCount: m['spoken_play_count'] as int? ?? 0,
      wpEarnedTotal: m['wp_earned_total'] as int? ?? 0,
      isActiveCycle: m['is_active_cycle'] as bool? ?? true,
      sungPlayedFirst: m['sung_played_first'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'student_id': studentId,
        'memory_item_id': memoryItemId,
        'cycle_id': cycleId,
        'mastery_level': masteryLevel,
        'last_practiced': lastPracticed != null ? Timestamp.fromDate(lastPracticed!) : null,
        'sung_play_count': sungPlayCount,
        'spoken_play_count': spokenPlayCount,
        'wp_earned_total': wpEarnedTotal,
        'is_active_cycle': isActiveCycle,
        'sung_played_first': sungPlayedFirst,
      };
}

// ─── Lumen State ──────────────────────────────────────────────────────────────
class LumenStateModel {
  final String id;
  final String studentId;
  final String cycleId;
  final int lumenLevel; // 1-5
  final int totalWp;
  final int currentWp;
  final List<String> unlockedItems;
  final int battleWins;
  final DateTime? lastBattleAt;
  final bool isActive;
  final DateTime createdAt;

  static const List<int> levelThresholds = [0, 200, 500, 1000, 1500];

  const LumenStateModel({
    required this.id,
    required this.studentId,
    required this.cycleId,
    required this.lumenLevel,
    required this.totalWp,
    required this.currentWp,
    required this.unlockedItems,
    required this.battleWins,
    this.lastBattleAt,
    required this.isActive,
    required this.createdAt,
  });

  int get wpForCurrentLevel => lumenLevel >= 2 ? levelThresholds[lumenLevel - 1] : 0;
  int get wpForNextLevel => lumenLevel < 5 ? levelThresholds[lumenLevel] : levelThresholds[4];
  int get wpProgressInLevel => currentWp - wpForCurrentLevel;
  int get wpNeededForNextLevel => wpForNextLevel - wpForCurrentLevel;
  double get levelProgress =>
      wpNeededForNextLevel > 0 ? wpProgressInLevel / wpNeededForNextLevel : 1.0;

  String get levelName {
    switch (lumenLevel) {
      case 1:
        return 'Initiate';
      case 2:
        return 'Apprentice';
      case 3:
        return 'Scholar';
      case 4:
        return 'Knight-Scholar';
      case 5:
        return 'Aquinas Scholar';
      default:
        return 'Initiate';
    }
  }

  factory LumenStateModel.fromMap(String id, Map<String, dynamic> m) {
    DateTime? parseTs(dynamic v) =>
        v is Timestamp ? v.toDate() : null;

    return LumenStateModel(
      id: id,
      studentId: m['student_id'] as String? ?? '',
      cycleId: m['cycle_id'] as String? ?? '',
      lumenLevel: m['lumen_level'] as int? ?? 1,
      totalWp: m['total_wp'] as int? ?? 0,
      currentWp: m['current_wp'] as int? ?? 0,
      unlockedItems: List<String>.from(m['unlocked_items'] as List? ?? []),
      battleWins: m['battle_wins'] as int? ?? 0,
      lastBattleAt: parseTs(m['last_battle_at']),
      isActive: m['is_active'] as bool? ?? true,
      createdAt: parseTs(m['created_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'student_id': studentId,
        'cycle_id': cycleId,
        'lumen_level': lumenLevel,
        'total_wp': totalWp,
        'current_wp': currentWp,
        'unlocked_items': unlockedItems,
        'battle_wins': battleWins,
        'last_battle_at': lastBattleAt != null ? Timestamp.fromDate(lastBattleAt!) : null,
        'is_active': isActive,
        'created_at': Timestamp.fromDate(createdAt),
      };

  LumenStateModel copyWith({
    int? lumenLevel,
    int? totalWp,
    int? currentWp,
    List<String>? unlockedItems,
    int? battleWins,
    DateTime? lastBattleAt,
  }) =>
      LumenStateModel(
        id: id,
        studentId: studentId,
        cycleId: cycleId,
        lumenLevel: lumenLevel ?? this.lumenLevel,
        totalWp: totalWp ?? this.totalWp,
        currentWp: currentWp ?? this.currentWp,
        unlockedItems: unlockedItems ?? this.unlockedItems,
        battleWins: battleWins ?? this.battleWins,
        lastBattleAt: lastBattleAt ?? this.lastBattleAt,
        isActive: isActive,
        createdAt: createdAt,
      );
}

// ─── Achievement ──────────────────────────────────────────────────────────────
class AchievementModel {
  final String id;
  final String studentId;
  final String cycleId;
  final String achievementType;
  final String awardedBy;
  final DateTime awardedAt;
  final bool isActiveCycle;

  const AchievementModel({
    required this.id,
    required this.studentId,
    required this.cycleId,
    required this.achievementType,
    required this.awardedBy,
    required this.awardedAt,
    required this.isActiveCycle,
  });

  static const Map<String, String> labels = {
    'subject_master_religion': 'Religion Master',
    'subject_master_scripture': 'Scripture Master',
    'subject_master_latin': 'Latin Master',
    'subject_master_grammar': 'Grammar Master',
    'subject_master_history': 'History Master',
    'subject_master_science': 'Science Master',
    'subject_master_math': 'Math Master',
    'subject_master_geography': 'Geography Master',
    'subject_master_great_words_1': 'Great Words I Master',
    'subject_master_great_words_2': 'Great Words II Master',
    'timeline_master': 'Timeline Master',
    'spiritual_master': 'Spiritual Master',
    'great_words_master': 'Great Words Master',
    'aquinas_scholar': 'Aquinas Scholar',
  };

  String get label => labels[achievementType] ?? achievementType;

  factory AchievementModel.fromMap(String id, Map<String, dynamic> m) =>
      AchievementModel(
        id: id,
        studentId: m['student_id'] as String? ?? '',
        cycleId: m['cycle_id'] as String? ?? '',
        achievementType: m['achievement_type'] as String? ?? '',
        awardedBy: m['awarded_by'] as String? ?? '',
        awardedAt: m['awarded_at'] is Timestamp
            ? (m['awarded_at'] as Timestamp).toDate()
            : DateTime.now(),
        isActiveCycle: m['is_active_cycle'] as bool? ?? true,
      );

  Map<String, dynamic> toMap() => {
        'student_id': studentId,
        'cycle_id': cycleId,
        'achievement_type': achievementType,
        'awarded_by': awardedBy,
        'awarded_at': Timestamp.fromDate(awardedAt),
        'is_active_cycle': isActiveCycle,
      };
}

// ─── PDF Resource ─────────────────────────────────────────────────────────────
class PdfResourceModel {
  final String id;
  final String cycleId;
  final String? subjectId;
  final int? unitNumber;
  final String title;
  final String pdfUrl;
  final String uploadedBy;
  final bool isSupplementary;
  final DateTime createdAt;

  const PdfResourceModel({
    required this.id,
    required this.cycleId,
    this.subjectId,
    this.unitNumber,
    required this.title,
    required this.pdfUrl,
    required this.uploadedBy,
    required this.isSupplementary,
    required this.createdAt,
  });

  factory PdfResourceModel.fromMap(String id, Map<String, dynamic> m) =>
      PdfResourceModel(
        id: id,
        cycleId: m['cycle_id'] as String? ?? '',
        subjectId: m['subject_id'] as String?,
        unitNumber: m['unit_number'] as int?,
        title: m['title'] as String? ?? '',
        pdfUrl: m['pdf_url'] as String? ?? '',
        uploadedBy: m['uploaded_by'] as String? ?? '',
        isSupplementary: m['is_supplementary'] as bool? ?? false,
        createdAt: m['created_at'] is Timestamp
            ? (m['created_at'] as Timestamp).toDate()
            : DateTime.now(),
      );
}

// ─── Custom Section ───────────────────────────────────────────────────────────
class CustomSectionModel {
  final String id;
  final String title;
  final String description;
  final String createdBy;
  final String? approvedBy;
  final String status; // pending, approved, rejected
  final String assignedScope; // all or class_id
  final String? subjectCategory;
  final DateTime createdAt;

  const CustomSectionModel({
    required this.id,
    required this.title,
    required this.description,
    required this.createdBy,
    this.approvedBy,
    required this.status,
    required this.assignedScope,
    this.subjectCategory,
    required this.createdAt,
  });

  factory CustomSectionModel.fromMap(String id, Map<String, dynamic> m) =>
      CustomSectionModel(
        id: id,
        title: m['title'] as String? ?? '',
        description: m['description'] as String? ?? '',
        createdBy: m['created_by'] as String? ?? '',
        approvedBy: m['approved_by'] as String?,
        status: m['status'] as String? ?? 'pending',
        assignedScope: m['assigned_scope'] as String? ?? 'all',
        subjectCategory: m['subject_category'] as String?,
        createdAt: m['created_at'] is Timestamp
            ? (m['created_at'] as Timestamp).toDate()
            : DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'created_by': createdBy,
        'approved_by': approvedBy,
        'status': status,
        'assigned_scope': assignedScope,
        'subject_category': subjectCategory,
        'created_at': Timestamp.fromDate(createdAt),
      };
}

// ─── Custom Section Item ──────────────────────────────────────────────────────
class CustomSectionItemModel {
  final String id;
  final String sectionId;
  final String? questionText;
  final String contentText;
  final String contentType;
  final String? audioUrl;
  final String? pdfUrl;
  final int sortOrder;

  const CustomSectionItemModel({
    required this.id,
    required this.sectionId,
    this.questionText,
    required this.contentText,
    required this.contentType,
    this.audioUrl,
    this.pdfUrl,
    required this.sortOrder,
  });

  factory CustomSectionItemModel.fromMap(String id, Map<String, dynamic> m) =>
      CustomSectionItemModel(
        id: id,
        sectionId: m['section_id'] as String? ?? '',
        questionText: m['question_text'] as String?,
        contentText: m['content_text'] as String? ?? '',
        contentType: m['content_type'] as String? ?? 'B',
        audioUrl: m['audio_url'] as String?,
        pdfUrl: m['pdf_url'] as String?,
        sortOrder: m['sort_order'] as int? ?? 0,
      );
}

// ─── App Settings (active cycle + unit) ───────────────────────────────────────
class MemorySettings {
  final String activeCycleId;
  final int currentUnit;

  const MemorySettings({
    required this.activeCycleId,
    required this.currentUnit,
  });

  static const MemorySettings defaults = MemorySettings(
    activeCycleId: 'cycle_2',
    currentUnit: 1,
  );

  factory MemorySettings.fromMap(Map<String, dynamic> m) => MemorySettings(
        activeCycleId: m['active_cycle_id'] as String? ?? 'cycle_2',
        currentUnit: m['current_unit'] as int? ?? 1,
      );

  Map<String, dynamic> toMap() => {
        'active_cycle_id': activeCycleId,
        'current_unit': currentUnit,
      };
}
