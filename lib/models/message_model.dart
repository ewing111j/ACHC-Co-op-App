// lib/models/message_model.dart

class MessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String content;
  final DateTime createdAt;
  final String familyId;
  final bool isAnnouncement;
  final List<String> readBy;
  final String? attachmentUrl;
  final String? attachmentType;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.content,
    required this.createdAt,
    required this.familyId,
    this.isAnnouncement = false,
    this.readBy = const [],
    this.attachmentUrl,
    this.attachmentType,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map, String id) {
    return MessageModel(
      id: id,
      senderId: map['senderId'] as String? ?? '',
      senderName: map['senderName'] as String? ?? 'Unknown',
      senderAvatar: map['senderAvatar'] as String?,
      content: map['content'] as String? ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['createdAt'] as dynamic).millisecondsSinceEpoch)
          : DateTime.now(),
      familyId: map['familyId'] as String? ?? '',
      isAnnouncement: map['isAnnouncement'] as bool? ?? false,
      readBy: List<String>.from(map['readBy'] as List? ?? []),
      attachmentUrl: map['attachmentUrl'] as String?,
      attachmentType: map['attachmentType'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'content': content,
      'createdAt': createdAt,
      'familyId': familyId,
      'isAnnouncement': isAnnouncement,
      'readBy': readBy,
      'attachmentUrl': attachmentUrl,
      'attachmentType': attachmentType,
    };
  }
}

class ChatRoom {
  final String id;
  final List<String> participants;
  final List<String> participantNames;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final String? lastSenderId;
  final bool isGroup;
  final String? groupName;
  final String? groupAvatar;

  const ChatRoom({
    required this.id,
    required this.participants,
    required this.participantNames,
    this.lastMessage,
    this.lastMessageTime,
    this.lastSenderId,
    this.isGroup = false,
    this.groupName,
    this.groupAvatar,
  });

  factory ChatRoom.fromMap(Map<String, dynamic> map, String id) {
    return ChatRoom(
      id: id,
      participants: List<String>.from(map['participants'] as List? ?? []),
      participantNames:
          List<String>.from(map['participantNames'] as List? ?? []),
      lastMessage: map['lastMessage'] as String?,
      lastMessageTime: map['lastMessageTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['lastMessageTime'] as dynamic).millisecondsSinceEpoch)
          : null,
      lastSenderId: map['lastSenderId'] as String?,
      isGroup: map['isGroup'] as bool? ?? false,
      groupName: map['groupName'] as String?,
      groupAvatar: map['groupAvatar'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'participantNames': participantNames,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime,
      'lastSenderId': lastSenderId,
      'isGroup': isGroup,
      'groupName': groupName,
      'groupAvatar': groupAvatar,
    };
  }
}
