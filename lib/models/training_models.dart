// lib/models/training_models.dart
// Data model for the Training module (P2-2).

import 'package:cloud_firestore/cloud_firestore.dart';

class TrainingCategory {
  static const String mentorOrientation = 'mentor_orientation';
  static const String parentResources   = 'parent_resources';
  static const String classicalEducation = 'classical_education';
  static const String coopPolicies      = 'coop_policies';

  static const Map<String, String> labels = {
    mentorOrientation:  'Mentor Orientation',
    parentResources:    'Parent Resources',
    classicalEducation: 'Classical Education',
    coopPolicies:       'Co-op Policies',
  };
}

class TrainingResourceModel {
  final String id;
  final String title;
  final String category;
  final String type; // 'video' | 'pdf'
  final String url;
  final String? thumbnailUrl;
  final String description;
  final int? durationSecs;
  final int? pageCount;
  final List<String> roles;
  final DateTime publishedAt;
  final int order;

  const TrainingResourceModel({
    required this.id,
    required this.title,
    required this.category,
    required this.type,
    required this.url,
    this.thumbnailUrl,
    required this.description,
    this.durationSecs,
    this.pageCount,
    required this.roles,
    required this.publishedAt,
    required this.order,
  });

  bool get isVideo => type == 'video';
  bool get isPdf   => type == 'pdf';

  String get durationLabel {
    if (durationSecs == null) return '';
    final m = durationSecs! ~/ 60;
    final s = durationSecs! % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  factory TrainingResourceModel.fromFirestore(
      Map<String, dynamic> data, String docId) {
    return TrainingResourceModel(
      id: docId,
      title: data['title'] as String? ?? '',
      category: data['category'] as String? ?? '',
      type: data['type'] as String? ?? 'pdf',
      url: data['url'] as String? ?? '',
      thumbnailUrl: data['thumbnailUrl'] as String?,
      description: data['description'] as String? ?? '',
      durationSecs: data['durationSecs'] as int?,
      pageCount: data['pageCount'] as int?,
      roles: List<String>.from(data['roles'] as List? ?? []),
      publishedAt:
          (data['publishedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      order: data['order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'category': category,
        'type': type,
        'url': url,
        'thumbnailUrl': thumbnailUrl,
        'description': description,
        'durationSecs': durationSecs,
        'pageCount': pageCount,
        'roles': roles,
        'publishedAt': FieldValue.serverTimestamp(),
        'order': order,
      };
}
