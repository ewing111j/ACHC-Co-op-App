// lib/models/checkin_model.dart

enum CheckInStatus { checkedIn, checkedOut, absent, excused }

class CheckInModel {
  final String id;
  final String userId;
  final String userName;
  final String familyId;
  final DateTime date;
  final CheckInStatus status;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final String? notes;
  final String? eventId;
  final String? eventName;

  const CheckInModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.familyId,
    required this.date,
    required this.status,
    this.checkInTime,
    this.checkOutTime,
    this.notes,
    this.eventId,
    this.eventName,
  });

  factory CheckInModel.fromMap(Map<String, dynamic> map, String id) {
    return CheckInModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      userName: map['userName'] as String? ?? '',
      familyId: map['familyId'] as String? ?? '',
      date: map['date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['date'] as dynamic).millisecondsSinceEpoch)
          : DateTime.now(),
      status: _statusFromString(map['status'] as String? ?? 'checkedIn'),
      checkInTime: map['checkInTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['checkInTime'] as dynamic).millisecondsSinceEpoch)
          : null,
      checkOutTime: map['checkOutTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['checkOutTime'] as dynamic).millisecondsSinceEpoch)
          : null,
      notes: map['notes'] as String?,
      eventId: map['eventId'] as String?,
      eventName: map['eventName'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'familyId': familyId,
      'date': date,
      'status': status.name,
      'checkInTime': checkInTime,
      'checkOutTime': checkOutTime,
      'notes': notes,
      'eventId': eventId,
      'eventName': eventName,
    };
  }

  static CheckInStatus _statusFromString(String s) {
    switch (s) {
      case 'checkedOut':
        return CheckInStatus.checkedOut;
      case 'absent':
        return CheckInStatus.absent;
      case 'excused':
        return CheckInStatus.excused;
      default:
        return CheckInStatus.checkedIn;
    }
  }
}
