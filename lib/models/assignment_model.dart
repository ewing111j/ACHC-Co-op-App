// lib/models/assignment_model.dart

enum AssignmentStatus { pending, submitted, graded, overdue }

class AssignmentModel {
  final String id;
  final String title;
  final String description;
  final String courseName;
  final String courseId;
  final DateTime dueDate;
  final AssignmentStatus status;
  final double? grade;
  final double? maxGrade;
  final String? submissionUrl;
  final bool fromMoodle;
  final String? assignedTo; // uid or 'all'
  final String familyId;
  final DateTime createdAt;

  const AssignmentModel({
    required this.id,
    required this.title,
    required this.description,
    required this.courseName,
    required this.courseId,
    required this.dueDate,
    required this.status,
    this.grade,
    this.maxGrade,
    this.submissionUrl,
    required this.fromMoodle,
    this.assignedTo,
    required this.familyId,
    required this.createdAt,
  });

  bool get isOverdue =>
      dueDate.isBefore(DateTime.now()) && status == AssignmentStatus.pending;

  factory AssignmentModel.fromMoodle(Map<String, dynamic> map) {
    final dueDate = map['duedate'] != null && map['duedate'] != 0
        ? DateTime.fromMillisecondsSinceEpoch(
            (map['duedate'] as int) * 1000)
        : DateTime.now().add(const Duration(days: 7));

    return AssignmentModel(
      id: 'moodle_${map['id']}',
      title: map['name'] as String? ?? 'Untitled',
      description: _stripHtml(map['intro'] as String? ?? ''),
      courseName: map['courseName'] as String? ?? 'Course',
      courseId: '${map['course']}',
      dueDate: dueDate,
      status: AssignmentStatus.pending,
      fromMoodle: true,
      familyId: '',
      createdAt: DateTime.now(),
    );
  }

  factory AssignmentModel.fromMap(Map<String, dynamic> map, String id) {
    return AssignmentModel(
      id: id,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      courseName: map['courseName'] as String? ?? '',
      courseId: map['courseId'] as String? ?? '',
      dueDate: map['dueDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['dueDate'] as dynamic).millisecondsSinceEpoch)
          : DateTime.now(),
      status: _statusFromString(map['status'] as String? ?? 'pending'),
      grade: (map['grade'] as num?)?.toDouble(),
      maxGrade: (map['maxGrade'] as num?)?.toDouble(),
      submissionUrl: map['submissionUrl'] as String?,
      fromMoodle: map['fromMoodle'] as bool? ?? false,
      assignedTo: map['assignedTo'] as String?,
      familyId: map['familyId'] as String? ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['createdAt'] as dynamic).millisecondsSinceEpoch)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'courseName': courseName,
      'courseId': courseId,
      'dueDate': dueDate,
      'status': status.name,
      'grade': grade,
      'maxGrade': maxGrade,
      'submissionUrl': submissionUrl,
      'fromMoodle': fromMoodle,
      'assignedTo': assignedTo,
      'familyId': familyId,
      'createdAt': createdAt,
    };
  }

  static AssignmentStatus _statusFromString(String s) {
    switch (s) {
      case 'submitted':
        return AssignmentStatus.submitted;
      case 'graded':
        return AssignmentStatus.graded;
      case 'overdue':
        return AssignmentStatus.overdue;
      default:
        return AssignmentStatus.pending;
    }
  }

  static String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .trim();
  }
}
