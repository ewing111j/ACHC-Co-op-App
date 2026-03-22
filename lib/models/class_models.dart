// lib/models/class_models.dart
// All models for the Classes feature
import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Class Color Palette ─────────────────────────────────────────────────────
const kClassColorOptions = [
  0xFF283593, // indigo-navy
  0xFF2E6B3E, // forest green
  0xFF7B1E3E, // deep rose
  0xFF5D3A1A, // dark brown
  0xFF4A1942, // deep purple
  0xFF1A4A7A, // dark blue
  0xFFC9A84C, // gold
  0xFF1E6B6B, // teal
  0xFF8B2500, // burnt orange
  0xFF2D3E7E, // mid navy
];

// ─── ClassModel ──────────────────────────────────────────────────────────────
class ClassModel {
  final String id;
  final String name;
  final String shortname;
  final List<String> mentorUids;
  final List<String> enrolledUids; // student UIDs
  final int colorValue; // ARGB int from kClassColorOptions
  final String gradeLevel; // e.g. "9-12", "7-8", "5-6", "K-4"
  // Grading: 'percent' or 'complete' — class default
  final String gradingMode;
  // For younger grades: show only complete/incomplete in gradebook
  final bool gradebookSimple;
  // Grade scale thresholds (percent mode)
  final double gradeA; // default 93
  final double gradeB; // default 85
  final double gradeC; // default 77
  final double gradeD; // default 70
  final DateTime? startDate;
  final String schoolYearId; // e.g. "2024-2025"
  final bool isArchived;
  final DateTime createdAt;

  const ClassModel({
    required this.id,
    required this.name,
    required this.shortname,
    this.mentorUids = const [],
    this.enrolledUids = const [],
    this.colorValue = 0xFF283593,
    this.gradeLevel = '',
    this.gradingMode = 'complete',
    this.gradebookSimple = false,
    this.gradeA = 93,
    this.gradeB = 85,
    this.gradeC = 77,
    this.gradeD = 70,
    this.startDate,
    this.schoolYearId = '',
    this.isArchived = false,
    required this.createdAt,
  });

  String letterGrade(double pct) {
    if (pct >= gradeA) return 'A';
    if (pct >= gradeB) return 'B';
    if (pct >= gradeC) return 'C';
    if (pct >= gradeD) return 'D';
    return 'F';
  }

  // Returns percentage given raw points (uses maxPoints context or raw value)
  double maxPct(double rawGrade) => rawGrade;

  factory ClassModel.fromMap(Map<String, dynamic> map, String id) {
    return ClassModel(
      id: id,
      name: map['name'] as String? ?? '',
      shortname: map['shortname'] as String? ?? '',
      mentorUids: List<String>.from(map['mentorUids'] as List? ?? []),
      enrolledUids: List<String>.from(map['enrolledUids'] as List? ?? []),
      colorValue: map['colorValue'] as int? ?? 0xFF283593,
      gradeLevel: map['gradeLevel'] as String? ?? '',
      gradingMode: map['gradingMode'] as String? ?? 'complete',
      gradebookSimple: map['gradebookSimple'] as bool? ?? false,
      gradeA: (map['gradeA'] as num?)?.toDouble() ?? 93,
      gradeB: (map['gradeB'] as num?)?.toDouble() ?? 85,
      gradeC: (map['gradeC'] as num?)?.toDouble() ?? 77,
      gradeD: (map['gradeD'] as num?)?.toDouble() ?? 70,
      startDate: map['startDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['startDate'] as dynamic).millisecondsSinceEpoch)
          : null,
      schoolYearId: map['schoolYearId'] as String? ?? '',
      isArchived: map['isArchived'] as bool? ?? false,
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['createdAt'] as dynamic).millisecondsSinceEpoch)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'shortname': shortname,
        'mentorUids': mentorUids,
        'enrolledUids': enrolledUids,
        'colorValue': colorValue,
        'gradeLevel': gradeLevel,
        'gradingMode': gradingMode,
        'gradebookSimple': gradebookSimple,
        'gradeA': gradeA,
        'gradeB': gradeB,
        'gradeC': gradeC,
        'gradeD': gradeD,
        'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
        'schoolYearId': schoolYearId,
        'isArchived': isArchived,
      };

  // Cache map: all dates as epoch ints for Hive JSON storage
  Map<String, dynamic> toCacheMap() => {
        'id': id,
        ...toMap(),
        'startDate': startDate?.millisecondsSinceEpoch,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory ClassModel.fromCacheMap(Map<String, dynamic> map) {
    return ClassModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      shortname: map['shortname'] as String? ?? '',
      mentorUids: List<String>.from(map['mentorUids'] as List? ?? []),
      enrolledUids: List<String>.from(map['enrolledUids'] as List? ?? []),
      colorValue: map['colorValue'] as int? ?? 0xFF283593,
      gradeLevel: map['gradeLevel'] as String? ?? '',
      gradingMode: map['gradingMode'] as String? ?? 'complete',
      gradebookSimple: map['gradebookSimple'] as bool? ?? false,
      gradeA: (map['gradeA'] as num?)?.toDouble() ?? 93,
      gradeB: (map['gradeB'] as num?)?.toDouble() ?? 85,
      gradeC: (map['gradeC'] as num?)?.toDouble() ?? 77,
      gradeD: (map['gradeD'] as num?)?.toDouble() ?? 70,
      startDate: map['startDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['startDate'] as int)
          : null,
      schoolYearId: map['schoolYearId'] as String? ?? '',
      isArchived: map['isArchived'] as bool? ?? false,
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : DateTime.now(),
    );
  }
}

// ─── ClassWeekModel ──────────────────────────────────────────────────────────
// Represents one week of a class, linked to admin coopCalendar entry
class ClassWeekModel {
  final String id; // weekKey e.g. "2025-01-06"
  final String classId;
  final int weekNumber; // 1-based within school year
  final String calendarLabel; // from coopCalendar e.g. "Week 4 Unit 6"
  final DateTime weekStart; // Monday
  final DateTime weekEnd; // Sunday
  final bool isBreak;
  final bool isHidden; // mentor can hide
  final DateTime? autoRevealDate; // mentor sets auto-reveal
  final String notes; // mentor notes for the week

  const ClassWeekModel({
    required this.id,
    required this.classId,
    required this.weekNumber,
    required this.calendarLabel,
    required this.weekStart,
    required this.weekEnd,
    this.isBreak = false,
    this.isHidden = false,
    this.autoRevealDate,
    this.notes = '',
  });

  String get displayLabel {
    final range =
        '${_fmt(weekStart)} – ${_fmt(weekEnd)}, ${weekStart.year}';
    if (calendarLabel.isNotEmpty) return '$calendarLabel: $range';
    return range;
  }

  String get shortLabel => calendarLabel.isNotEmpty ? calendarLabel : _fmt(weekStart);

  String _fmt(DateTime d) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month]} ${d.day}';
  }

  factory ClassWeekModel.fromMap(Map<String, dynamic> map, String id, String classId) {
    return ClassWeekModel(
      id: id,
      classId: classId,
      weekNumber: map['weekNumber'] as int? ?? 0,
      calendarLabel: map['calendarLabel'] as String? ?? '',
      weekStart: map['weekStart'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['weekStart'] as dynamic).millisecondsSinceEpoch)
          : DateTime.now(),
      weekEnd: map['weekEnd'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['weekEnd'] as dynamic).millisecondsSinceEpoch)
          : DateTime.now(),
      isBreak: map['isBreak'] as bool? ?? false,
      isHidden: map['isHidden'] as bool? ?? false,
      autoRevealDate: map['autoRevealDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['autoRevealDate'] as dynamic).millisecondsSinceEpoch)
          : null,
      notes: map['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'classId': classId,
        'weekNumber': weekNumber,
        'calendarLabel': calendarLabel,
        'weekStart': Timestamp.fromDate(weekStart),
        'weekEnd': Timestamp.fromDate(weekEnd),
        'isBreak': isBreak,
        'isHidden': isHidden,
        'autoRevealDate':
            autoRevealDate != null ? Timestamp.fromDate(autoRevealDate!) : null,
        'notes': notes,
      };
}

// ─── HomeworkModel ───────────────────────────────────────────────────────────
// A single homework/assignment item within a class week
class HomeworkModel {
  final String id;
  final String classId;
  final String weekId;
  final String title;
  final String description;
  final List<String> checklist; // ["Read pages 34-37", "Answer questions 1-5"]
  final DateTime dueDate;
  // 'complete' = complete/incomplete only, 'percent' = 0-100%
  final String gradingMode;
  final double? maxPoints; // for percent mode (null = raw %)
  final int sortOrder;
  int get order => sortOrder; // alias used by UI
  final bool isHidden;
  final DateTime createdAt;

  const HomeworkModel({
    required this.id,
    required this.classId,
    required this.weekId,
    required this.title,
    this.description = '',
    this.checklist = const [],
    required this.dueDate,
    this.gradingMode = 'complete',
    this.maxPoints,
    this.sortOrder = 0,
    this.isHidden = false,
    required this.createdAt,
  });

  // 4-arg factory so gradebook_screen can pass classId + weekId overrides
  factory HomeworkModel.fromMap(Map<String, dynamic> map, String id,
      [String? classIdOverride, String? weekIdOverride]) {
    return HomeworkModel(
      id: id,
      classId: classIdOverride ?? map['classId'] as String? ?? '',
      weekId: weekIdOverride ?? map['weekId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      checklist: List<String>.from(map['checklist'] as List? ?? []),
      dueDate: map['dueDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['dueDate'] as dynamic).millisecondsSinceEpoch)
          : DateTime.now(),
      gradingMode: map['gradingMode'] as String? ?? 'complete',
      maxPoints: (map['maxPoints'] as num?)?.toDouble(),
      sortOrder: map['order'] as int? ?? map['sortOrder'] as int? ?? 0,
      isHidden: map['isHidden'] as bool? ?? false,
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['createdAt'] as dynamic).millisecondsSinceEpoch)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'classId': classId,
        'weekId': weekId,
        'title': title,
        'description': description,
        'checklist': checklist,
        'dueDate': Timestamp.fromDate(dueDate),
        'gradingMode': gradingMode,
        'maxPoints': maxPoints,
        'sortOrder': sortOrder,
        'isHidden': isHidden,
      };
}

// ─── SubmissionModel ─────────────────────────────────────────────────────────
// A student's response to a homework item
class SubmissionModel {
  final String id;
  final String homeworkId;
  final String classId;
  final String weekId;
  final String studentUid;
  final String studentName;
  // For complete mode: 'complete' | 'incomplete'
  // For percent mode: numeric stored in grade field
  final String status; // 'complete' | 'incomplete' | 'submitted' | 'graded'
  final double? grade; // 0-100 for percent mode
  final String feedback;
  final String? fileUrl;
  final String? fileName;
  final DateTime submittedAt;
  final DateTime? gradedAt;
  // Checklist item completion: key is the item text (string), value is bool
  final Map<String, bool> checklistDone;

  const SubmissionModel({
    required this.id,
    required this.homeworkId,
    required this.classId,
    required this.weekId,
    required this.studentUid,
    required this.studentName,
    this.status = 'incomplete',
    this.grade,
    this.feedback = '',
    this.fileUrl,
    this.fileName,
    required this.submittedAt,
    this.gradedAt,
    this.checklistDone = const {},
  });

  bool get isComplete =>
      status == 'complete' || status == 'submitted' || status == 'graded';

  double? get percentage {
    if (grade != null) return grade;
    return null;
  }

  factory SubmissionModel.fromMap(Map<String, dynamic> map, String id) {
    final rawChecklist = map['checklistDone'] as Map? ?? {};
    // Support both string-key (item text) and int-key (legacy index) formats
    final checklistDone = <String, bool>{};
    rawChecklist.forEach((k, v) {
      checklistDone[k.toString()] = v as bool? ?? false;
    });
    return SubmissionModel(
      id: id,
      homeworkId: map['homeworkId'] as String? ?? '',
      classId: map['classId'] as String? ?? '',
      weekId: map['weekId'] as String? ?? '',
      studentUid: map['studentUid'] as String? ?? '',
      studentName: map['studentName'] as String? ?? '',
      status: map['status'] as String? ?? 'incomplete',
      grade: (map['grade'] as num?)?.toDouble(),
      feedback: map['feedback'] as String? ?? '',
      fileUrl: map['fileUrl'] as String?,
      fileName: map['fileName'] as String?,
      submittedAt: map['submittedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['submittedAt'] as dynamic).millisecondsSinceEpoch)
          : DateTime.now(),
      gradedAt: map['gradedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['gradedAt'] as dynamic).millisecondsSinceEpoch)
          : null,
      checklistDone: checklistDone,
    );
  }

  Map<String, dynamic> toMap() {
    final cl = <String, bool>{};
    checklistDone.forEach((k, v) => cl[k] = v);
    return {
      'homeworkId': homeworkId,
      'classId': classId,
      'weekId': weekId,
      'studentUid': studentUid,
      'studentName': studentName,
      'status': status,
      'grade': grade,
      'feedback': feedback,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'submittedAt': Timestamp.fromDate(submittedAt),
      'gradedAt': gradedAt != null ? Timestamp.fromDate(gradedAt!) : null,
      'checklistDone': cl,
    };
  }
}

// ─── ClassFileModel ──────────────────────────────────────────────────────────
class ClassFileModel {
  final String id;
  final String classId;
  final String name;
  final String url;
  final String fileType; // 'pdf'|'video'|'url'|'doc'|'image'|'other'
  final bool isPinned;
  final String? weekId; // null = always visible (pinned resource)
  final String uploaderUid;
  final String uploaderName;
  final DateTime uploadedAt;

  const ClassFileModel({
    required this.id,
    required this.classId,
    required this.name,
    required this.url,
    this.fileType = 'other',
    this.isPinned = false,
    this.weekId,
    required this.uploaderUid,
    required this.uploaderName,
    required this.uploadedAt,
  });

  factory ClassFileModel.fromMap(Map<String, dynamic> map, String id) {
    return ClassFileModel(
      id: id,
      classId: map['classId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      url: map['url'] as String? ?? '',
      fileType: map['fileType'] as String? ?? 'other',
      isPinned: map['isPinned'] as bool? ?? false,
      weekId: map['weekId'] as String?,
      uploaderUid: map['uploaderUid'] as String? ?? '',
      uploaderName: map['uploaderName'] as String? ?? '',
      uploadedAt: map['uploadedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['uploadedAt'] as dynamic).millisecondsSinceEpoch)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'classId': classId,
        'name': name,
        'url': url,
        'fileType': fileType,
        'isPinned': isPinned,
        'weekId': weekId,
        'uploaderUid': uploaderUid,
        'uploaderName': uploaderName,
        'uploadedAt': Timestamp.fromDate(uploadedAt),
      };
}

// ─── ClassAnnouncementModel ──────────────────────────────────────────────────
class ClassAnnouncementModel {
  final String id;
  final String classId;
  final String title;
  final String content;
  final String authorUid;
  final String authorName;
  final bool postedToGlobalFeed;
  final int commentCount;
  final DateTime createdAt;

  const ClassAnnouncementModel({
    required this.id,
    required this.classId,
    required this.title,
    required this.content,
    required this.authorUid,
    required this.authorName,
    this.postedToGlobalFeed = false,
    this.commentCount = 0,
    required this.createdAt,
  });

  factory ClassAnnouncementModel.fromMap(Map<String, dynamic> map, String id) {
    return ClassAnnouncementModel(
      id: id,
      classId: map['classId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      authorUid: map['authorUid'] as String? ?? '',
      authorName: map['authorName'] as String? ?? '',
      postedToGlobalFeed: map['postedToGlobalFeed'] as bool? ?? false,
      commentCount: map['commentCount'] as int? ?? 0,
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['createdAt'] as dynamic).millisecondsSinceEpoch)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'classId': classId,
        'title': title,
        'content': content,
        'authorUid': authorUid,
        'authorName': authorName,
        'postedToGlobalFeed': postedToGlobalFeed,
        'commentCount': commentCount,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

// ─── AskMentorModel ──────────────────────────────────────────────────────────
class AskMentorModel {
  final String id;
  final String classId;
  final String question;
  final String authorUid;
  final String authorName;
  // 'public' = all students see it; 'private' = mentor + admins only
  final String visibility;
  final int replyCount;
  final bool isAnswered;
  final DateTime createdAt;

  const AskMentorModel({
    required this.id,
    required this.classId,
    required this.question,
    required this.authorUid,
    required this.authorName,
    this.visibility = 'public',
    this.replyCount = 0,
    this.isAnswered = false,
    required this.createdAt,
  });

  bool get isPrivate => visibility == 'private';

  factory AskMentorModel.fromMap(Map<String, dynamic> map, String id) {
    return AskMentorModel(
      id: id,
      classId: map['classId'] as String? ?? '',
      question: map['question'] as String? ?? '',
      authorUid: map['authorUid'] as String? ?? '',
      authorName: map['authorName'] as String? ?? '',
      visibility: map['visibility'] as String? ?? 'public',
      replyCount: map['replyCount'] as int? ?? 0,
      isAnswered: map['isAnswered'] as bool? ?? false,
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['createdAt'] as dynamic).millisecondsSinceEpoch)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'classId': classId,
        'question': question,
        'authorUid': authorUid,
        'authorName': authorName,
        'visibility': visibility,
        'replyCount': replyCount,
        'isAnswered': isAnswered,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
