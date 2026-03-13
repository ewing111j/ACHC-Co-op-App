// lib/models/event_model.dart

class EventModel {
  final String id;
  final String title;
  final String? description;
  final DateTime startDate;
  final DateTime? endDate;
  final bool allDay;
  final String? location;
  final String color;
  final String createdBy;
  final String familyId;
  final bool isPublic;
  final DateTime createdAt;

  const EventModel({
    required this.id,
    required this.title,
    this.description,
    required this.startDate,
    this.endDate,
    this.allDay = false,
    this.location,
    this.color = '#2196F3',
    required this.createdBy,
    required this.familyId,
    this.isPublic = false,
    required this.createdAt,
  });

  factory EventModel.fromMap(Map<String, dynamic> map, String id) {
    return EventModel(
      id: id,
      title: map['title'] as String? ?? '',
      description: map['description'] as String?,
      startDate: map['startDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['startDate'] as dynamic).millisecondsSinceEpoch)
          : DateTime.now(),
      endDate: map['endDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['endDate'] as dynamic).millisecondsSinceEpoch)
          : null,
      allDay: map['allDay'] as bool? ?? false,
      location: map['location'] as String?,
      color: map['color'] as String? ?? '#2196F3',
      createdBy: map['createdBy'] as String? ?? '',
      familyId: map['familyId'] as String? ?? '',
      isPublic: map['isPublic'] as bool? ?? false,
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
      'startDate': startDate,
      'endDate': endDate,
      'allDay': allDay,
      'location': location,
      'color': color,
      'createdBy': createdBy,
      'familyId': familyId,
      'isPublic': isPublic,
      'createdAt': createdAt,
    };
  }
}
