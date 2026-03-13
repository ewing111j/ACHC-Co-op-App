// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/assignment_model.dart';
import '../models/message_model.dart';
import '../models/event_model.dart';
import '../models/photo_model.dart';
import '../models/feed_model.dart';
import '../models/checkin_model.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── ASSIGNMENTS ────────────────────────────────────────────
  Stream<List<AssignmentModel>> streamAssignments(
      String familyId, String? userId) {
    Query query = _db
        .collection('assignments')
        .where('familyId', isEqualTo: familyId);

    return query.snapshots().map((snap) {
      final list = snap.docs
          .map((d) =>
              AssignmentModel.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();
      list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      return list;
    });
  }

  Future<void> saveAssignments(List<AssignmentModel> assignments) async {
    final batch = _db.batch();
    for (final a in assignments) {
      final ref = _db.collection('assignments').doc(a.id);
      batch.set(ref, {...a.toMap(), 'createdAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> updateAssignmentStatus(
      String id, AssignmentStatus status) async {
    await _db
        .collection('assignments')
        .doc(id)
        .update({'status': status.name});
  }

  // ─── MESSAGES / CHAT ────────────────────────────────────────
  Stream<List<ChatRoom>> streamChatRooms(String userId) {
    return _db
        .collection('chatRooms')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => ChatRoom.fromMap(d.data(), d.id))
          .toList();
      list.sort((a, b) {
        if (a.lastMessageTime == null) return 1;
        if (b.lastMessageTime == null) return -1;
        return b.lastMessageTime!.compareTo(a.lastMessageTime!);
      });
      return list;
    });
  }

  Stream<List<MessageModel>> streamMessages(String roomId) {
    return _db
        .collection('chatRooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => MessageModel.fromMap(d.data(), d.id))
            .toList());
  }

  Future<String> createOrGetDirectRoom(
      String userId1, String name1, String userId2, String name2) async {
    // Check if DM room already exists
    final existing = await _db
        .collection('chatRooms')
        .where('participants', arrayContains: userId1)
        .where('isGroup', isEqualTo: false)
        .get();

    for (final doc in existing.docs) {
      final data = doc.data();
      final participants =
          List<String>.from(data['participants'] as List? ?? []);
      if (participants.contains(userId2)) return doc.id;
    }

    // Create new room
    final ref = _db.collection('chatRooms').doc();
    await ref.set({
      'participants': [userId1, userId2],
      'participantNames': [name1, name2],
      'isGroup': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> sendMessage(String roomId, MessageModel msg) async {
    final batch = _db.batch();
    final msgRef =
        _db.collection('chatRooms').doc(roomId).collection('messages').doc();
    batch.set(msgRef, {
      ...msg.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(_db.collection('chatRooms').doc(roomId), {
      'lastMessage': msg.content,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': msg.senderId,
    });
    await batch.commit();
  }

  // ─── EVENTS / CALENDAR ──────────────────────────────────────
  Stream<List<EventModel>> streamEvents(String familyId) {
    return _db
        .collection('events')
        .where('familyId', isEqualTo: familyId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => EventModel.fromMap(d.data(), d.id))
          .toList();
      list.sort((a, b) => a.startDate.compareTo(b.startDate));
      return list;
    });
  }

  Future<void> createEvent(EventModel event) async {
    await _db.collection('events').doc(event.id).set(
        {...event.toMap(), 'createdAt': FieldValue.serverTimestamp()});
  }

  Future<void> deleteEvent(String eventId) async {
    await _db.collection('events').doc(eventId).delete();
  }

  // ─── PHOTOS ─────────────────────────────────────────────────
  Stream<List<PhotoModel>> streamPhotos(String familyId) {
    return _db
        .collection('photos')
        .where('familyId', isEqualTo: familyId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => PhotoModel.fromMap(d.data(), d.id))
          .toList();
      list.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
      return list;
    });
  }

  Future<void> savePhoto(PhotoModel photo) async {
    await _db.collection('photos').doc(photo.id).set(
        {...photo.toMap(), 'uploadedAt': FieldValue.serverTimestamp()});
  }

  Future<List<PhotoAlbum>> getAlbums(String familyId) async {
    try {
      final snap = await _db
          .collection('albums')
          .where('familyId', isEqualTo: familyId)
          .get();
      return snap.docs
          .map((d) => PhotoAlbum.fromMap(d.data(), d.id))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // ─── FEEDS ──────────────────────────────────────────────────
  Stream<List<FeedModel>> streamFeeds(String familyId) {
    return _db
        .collection('feeds')
        .where('familyId', isEqualTo: familyId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => FeedModel.fromMap(d.data(), d.id))
          .toList();
      list.sort((a, b) {
        return b.createdAt.compareTo(a.createdAt);
      });
      return list;
    });
  }

  Future<void> createFeed(FeedModel feed) async {
    await _db.collection('feeds').doc(feed.id).set(
        {...feed.toMap(), 'createdAt': FieldValue.serverTimestamp()});
  }

  Future<void> toggleLike(String feedId, String userId) async {
    final ref = _db.collection('feeds').doc(feedId);
    final doc = await ref.get();
    if (!doc.exists) return;
    final likes = List<String>.from(doc.data()?['likes'] as List? ?? []);
    if (likes.contains(userId)) {
      await ref.update({'likes': FieldValue.arrayRemove([userId])});
    } else {
      await ref.update({'likes': FieldValue.arrayUnion([userId])});
    }
  }

  // ─── CHECK-IN ───────────────────────────────────────────────
  Stream<List<CheckInModel>> streamCheckIns(String familyId, DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return _db
        .collection('checkins')
        .where('familyId', isEqualTo: familyId)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((d) => CheckInModel.fromMap(d.data(), d.id))
          .where((c) =>
              c.date.isAfter(startOfDay) && c.date.isBefore(endOfDay))
          .toList();
    });
  }

  Future<void> checkIn(CheckInModel checkIn) async {
    await _db.collection('checkins').doc(checkIn.id).set(
        {...checkIn.toMap(), 'checkInTime': FieldValue.serverTimestamp()});
  }

  Future<void> checkOut(String checkInId) async {
    await _db.collection('checkins').doc(checkInId).update(
        {'checkOutTime': FieldValue.serverTimestamp(), 'status': 'checkedOut'});
  }

  // ─── FILES ──────────────────────────────────────────────────
  Stream<List<Map<String, dynamic>>> streamFiles(String familyId) {
    return _db
        .collection('files')
        .where('familyId', isEqualTo: familyId)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();
      list.sort((a, b) {
        final aTime = a['uploadedAt'];
        final bTime = b['uploadedAt'];
        if (aTime == null || bTime == null) return 0;
        final aMs = (aTime as dynamic).millisecondsSinceEpoch as int;
        final bMs = (bTime as dynamic).millisecondsSinceEpoch as int;
        return bMs.compareTo(aMs);
      });
      return list;
    });
  }

  Future<void> saveFile(Map<String, dynamic> fileData) async {
    final ref = _db.collection('files').doc();
    await ref.set({...fileData, 'uploadedAt': FieldValue.serverTimestamp()});
  }

  // ─── FAMILY MEMBERS ─────────────────────────────────────────
  Future<List<UserModel>> getFamilyMembers(String familyId) async {
    try {
      final snap = await _db
          .collection('users')
          .where('familyId', isEqualTo: familyId)
          .get();
      return snap.docs
          .map((d) => UserModel.fromMap(d.data(), d.id))
          .toList();
    } catch (e) {
      debugPrint('Error getting family members: $e');
      return [];
    }
  }
}
