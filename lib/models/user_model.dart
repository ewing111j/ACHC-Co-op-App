// lib/models/user_model.dart

enum UserRole { parent, kid, admin }

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final String? parentUid; // For kid accounts
  final String? familyId;
  final List<String> kidUids; // For parent accounts
  final String? avatarUrl;
  final String? moodleToken;
  final String? moodleUrl;
  final DateTime createdAt;
  final bool isActive;
  final String? fcmToken;

  const UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.parentUid,
    this.familyId,
    this.kidUids = const [],
    this.avatarUrl,
    this.moodleToken,
    this.moodleUrl,
    required this.createdAt,
    this.isActive = true,
    this.fcmToken,
  });

  bool get isParent => role == UserRole.parent;
  bool get isKid => role == UserRole.kid;
  bool get isAdmin => role == UserRole.admin;

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      role: _roleFromString(map['role'] as String? ?? 'parent'),
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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'role': role.name,
      'parentUid': parentUid,
      'familyId': familyId,
      'kidUids': kidUids,
      'avatarUrl': avatarUrl,
      'moodleToken': moodleToken,
      'moodleUrl': moodleUrl,
      'isActive': isActive,
      'fcmToken': fcmToken,
    };
  }

  UserModel copyWith({
    String? displayName,
    String? avatarUrl,
    String? moodleToken,
    String? moodleUrl,
    List<String>? kidUids,
    String? fcmToken,
    bool? isActive,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      role: role,
      parentUid: parentUid,
      familyId: familyId,
      kidUids: kidUids ?? this.kidUids,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      moodleToken: moodleToken ?? this.moodleToken,
      moodleUrl: moodleUrl ?? this.moodleUrl,
      createdAt: createdAt,
      isActive: isActive ?? this.isActive,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }

  static UserRole _roleFromString(String role) {
    switch (role) {
      case 'kid':
        return UserRole.kid;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.parent;
    }
  }
}
