// lib/models/event_model.dart

class EventModel {
  final String id;
  final String title;
  final String description;
  final String? location;
  final DateTime startDate;
  final DateTime endDate;
  final String createdBy;
  final bool isRecurring;
  final DateTime createdAt;

  const EventModel({
    required this.id,
    required this.title,
    required this.description,
    this.location,
    required this.startDate,
    required this.endDate,
    required this.createdBy,
    this.isRecurring = false,
    required this.createdAt,
  });

  factory EventModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime _ts(dynamic v, DateTime fallback) {
      if (v == null) return fallback;
      try {
        return DateTime.fromMillisecondsSinceEpoch(
            (v as dynamic).millisecondsSinceEpoch as int);
      } catch (_) {
        return fallback;
      }
    }

    return EventModel(
      id: id,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      location: map['location'] as String?,
      startDate: _ts(map['startDate'], DateTime.now()),
      endDate: _ts(map['endDate'], DateTime.now().add(const Duration(hours: 1))),
      createdBy: map['createdBy'] as String? ?? '',
      isRecurring: map['isRecurring'] as bool? ?? false,
      createdAt: _ts(map['createdAt'], DateTime.now()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'location': location,
      'startDate': startDate,
      'endDate': endDate,
      'createdBy': createdBy,
      'isRecurring': isRecurring,
      'createdAt': createdAt,
    };
  }
}
