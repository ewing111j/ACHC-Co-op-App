// lib/models/feed_model.dart

enum FeedType { announcement, social, prayer }

class FeedModel {
  final String id;
  final FeedType type;
  final String title;
  final String content;
  final String authorId;
  final String authorName;
  final List<String> likedBy;
  final int commentCount;
  final List<String> pollOptions;
  final Map<String, dynamic> pollVotes;
  final bool inKidFeed;
  final DateTime createdAt;

  const FeedModel({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.authorId,
    required this.authorName,
    required this.likedBy,
    required this.commentCount,
    required this.pollOptions,
    required this.pollVotes,
    required this.inKidFeed,
    required this.createdAt,
  });

  factory FeedModel.fromMap(Map<String, dynamic> map, String id) {
    FeedType type;
    switch (map['type'] as String? ?? 'social') {
      case 'announcement':
        type = FeedType.announcement;
        break;
      case 'prayer':
        type = FeedType.prayer;
        break;
      default:
        type = FeedType.social;
    }

    return FeedModel(
      id: id,
      type: type,
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      authorId: map['authorId'] as String? ?? '',
      authorName: map['authorName'] as String? ?? 'Unknown',
      likedBy: List<String>.from(map['likedBy'] as List? ?? []),
      commentCount: map['commentCount'] as int? ?? 0,
      pollOptions: List<String>.from(map['pollOptions'] as List? ?? []),
      pollVotes: Map<String, dynamic>.from(map['pollVotes'] as Map? ?? {}),
      inKidFeed: map['inKidFeed'] as bool? ?? false,
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['createdAt'] as dynamic).millisecondsSinceEpoch)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'title': title,
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      'likedBy': likedBy,
      'commentCount': commentCount,
      'pollOptions': pollOptions,
      'pollVotes': pollVotes,
      'inKidFeed': inKidFeed,
      'createdAt': createdAt,
    };
  }
}
