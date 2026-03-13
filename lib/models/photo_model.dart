// lib/models/photo_model.dart

class PhotoModel {
  final String id;
  final String url;
  final String? thumbnailUrl;
  final String caption;
  final String uploadedBy;
  final String uploaderName;
  final String familyId;
  final String? albumId;
  final DateTime uploadedAt;
  final List<String> tags;

  const PhotoModel({
    required this.id,
    required this.url,
    this.thumbnailUrl,
    required this.caption,
    required this.uploadedBy,
    required this.uploaderName,
    required this.familyId,
    this.albumId,
    required this.uploadedAt,
    this.tags = const [],
  });

  factory PhotoModel.fromMap(Map<String, dynamic> map, String id) {
    return PhotoModel(
      id: id,
      url: map['url'] as String? ?? '',
      thumbnailUrl: map['thumbnailUrl'] as String?,
      caption: map['caption'] as String? ?? '',
      uploadedBy: map['uploadedBy'] as String? ?? '',
      uploaderName: map['uploaderName'] as String? ?? '',
      familyId: map['familyId'] as String? ?? '',
      albumId: map['albumId'] as String?,
      uploadedAt: map['uploadedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['uploadedAt'] as dynamic).millisecondsSinceEpoch)
          : DateTime.now(),
      tags: List<String>.from(map['tags'] as List? ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'thumbnailUrl': thumbnailUrl,
      'caption': caption,
      'uploadedBy': uploadedBy,
      'uploaderName': uploaderName,
      'familyId': familyId,
      'albumId': albumId,
      'uploadedAt': uploadedAt,
      'tags': tags,
    };
  }
}

class PhotoAlbum {
  final String id;
  final String name;
  final String? coverUrl;
  final String familyId;
  final int photoCount;
  final DateTime createdAt;

  const PhotoAlbum({
    required this.id,
    required this.name,
    this.coverUrl,
    required this.familyId,
    this.photoCount = 0,
    required this.createdAt,
  });

  factory PhotoAlbum.fromMap(Map<String, dynamic> map, String id) {
    return PhotoAlbum(
      id: id,
      name: map['name'] as String? ?? '',
      coverUrl: map['coverUrl'] as String?,
      familyId: map['familyId'] as String? ?? '',
      photoCount: map['photoCount'] as int? ?? 0,
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['createdAt'] as dynamic).millisecondsSinceEpoch)
          : DateTime.now(),
    );
  }
}
