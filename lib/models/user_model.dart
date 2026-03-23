// lib/models/user_model.dart

enum UserRole { parent, student, admin, mentor }

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final bool isMentor; // can be true alongside parent role
  final List<String> mentorClassIds; // classes this user mentors
  final String? parentUid;
  final String? familyId;
  final List<String> kidUids;
  final String? avatarUrl;
  final String? moodleToken;
  final String? moodleUrl;
  final DateTime createdAt;
  final bool isActive;
  final String? fcmToken;
  final bool isYoungLearner; // per-student flag for simplified UI mode

  const UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.isMentor = false,
    this.mentorClassIds = const [],
    this.parentUid,
    this.familyId,
    this.kidUids = const [],
    this.avatarUrl,
    this.moodleToken,
    this.moodleUrl,
    required this.createdAt,
    this.isActive = true,
    this.fcmToken,
    this.isYoungLearner = false,
  });

  bool get isParent => role == UserRole.parent;
  bool get isStudent => role == UserRole.student;
  bool get isKid => role == UserRole.student; // legacy alias
  bool get isAdmin => role == UserRole.admin;
  // A user is a mentor if role==mentor OR isMentor flag is true (parent-mentor)
  bool get canMentor => role == UserRole.mentor || isMentor;
  // Can edit classes: mentor or admin
  bool get canEditClasses => canMentor || isAdmin;

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      role: _roleFromString(map['role'] as String? ?? 'parent'),
      isMentor: map['isMentor'] as bool? ?? false,
      mentorClassIds: List<String>.from(map['mentorClassIds'] as List? ?? []),
      parentUid: map['parentUid'] as String?,
      familyId: map['familyId'] as String?,
      kidUids: List<String>.from(map['kidUids'] as List? ?? []),
      avatarUrl: map['avatarUrl'] as String?,
      moodleToken: map['moodleToken'] as String?,
      moodleUrl: map['moodleUrl'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['createdAt'] as dynamic).millisecondsSinceEpoch)
          : DateTime.now(),
      isActive: map['isActive'] as bool? ?? true,
      fcmToken: map['fcmToken'] as String?,
      isYoungLearner: map['is_young_learner'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'role': role == UserRole.student ? 'student' : role.name,
      'isMentor': isMentor,
      'mentorClassIds': mentorClassIds,
      'parentUid': parentUid,
      'familyId': familyId,
      'kidUids': kidUids,
      'avatarUrl': avatarUrl,
      'moodleToken': moodleToken,
      'moodleUrl': moodleUrl,
      'isActive': isActive,
      'fcmToken': fcmToken,
      'is_young_learner': isYoungLearner,
    };
  }

  UserModel copyWith({
    String? displayName,
    String? avatarUrl,
    String? moodleToken,
    String? moodleUrl,
    List<String>? kidUids,
    List<String>? mentorClassIds,
    bool? isMentor,
    String? fcmToken,
    bool? isActive,
    bool? isYoungLearner,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      role: role,
      isMentor: isMentor ?? this.isMentor,
      mentorClassIds: mentorClassIds ?? this.mentorClassIds,
      parentUid: parentUid,
      familyId: familyId,
      kidUids: kidUids ?? this.kidUids,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      moodleToken: moodleToken ?? this.moodleToken,
      moodleUrl: moodleUrl ?? this.moodleUrl,
      createdAt: createdAt,
      isActive: isActive ?? this.isActive,
      fcmToken: fcmToken ?? this.fcmToken,
      isYoungLearner: isYoungLearner ?? this.isYoungLearner,
    );
  }

  static UserRole _roleFromString(String role) {
    switch (role) {
      case 'kid':
      case 'student':
        return UserRole.student;
      case 'admin':
        return UserRole.admin;
      case 'mentor':
        return UserRole.mentor;
      default:
        return UserRole.parent;
    }
  }
}
