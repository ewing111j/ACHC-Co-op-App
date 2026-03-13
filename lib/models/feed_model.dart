// lib/models/feed_model.dart

enum FeedType { announcement, news, event, photo, resource }

class FeedModel {
  final String id;
  final String title;
  final String content;
  final FeedType type;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final String familyId;
  final DateTime createdAt;
  final List<String> likes;
  final int commentCount;
  final String? imageUrl;
  final String? linkUrl;
  final bool isPinned;

  const FeedModel({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    required this.familyId,
    required this.createdAt,
    this.likes = const [],
    this.commentCount = 0,
    this.imageUrl,
    this.linkUrl,
    this.isPinned = false,
  });

  factory FeedModel.fromMap(Map<String, dynamic> map, String id) {
    return FeedModel(
      id: id,
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      type: _typeFromString(map['type'] as String? ?? 'announcement'),
      authorId: map['authorId'] as String? ?? '',
      authorName: map['authorName'] as String? ?? 'Admin',
      authorAvatar: map['authorAvatar'] as String?,
      familyId: map['familyId'] as String? ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['createdAt'] as dynamic).millisecondsSinceEpoch)
          : DateTime.now(),
      likes: List<String>.from(map['likes'] as List? ?? []),
      commentCount: map['commentCount'] as int? ?? 0,
      imageUrl: map['imageUrl'] as String?,
      linkUrl: map['linkUrl'] as String?,
      isPinned: map['isPinned'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'type': type.name,
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'familyId': familyId,
      'createdAt': createdAt,
      'likes': likes,
      'commentCount': commentCount,
      'imageUrl': imageUrl,
      'linkUrl': linkUrl,
      'isPinned': isPinned,
    };
  }

  static FeedType _typeFromString(String s) {
    switch (s) {
      case 'news':
        return FeedType.news;
      case 'event':
        return FeedType.event;
      case 'photo':
        return FeedType.photo;
      case 'resource':
        return FeedType.resource;
      default:
        return FeedType.announcement;
    }
  }
}
