// lib/services/moodle_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/assignment_model.dart';

class MoodleService {
  String? _baseUrl;
  String? _token;

  bool get isConfigured => _baseUrl != null && _token != null;

  void configure(String baseUrl, String token) {
    _baseUrl = baseUrl.trimRight().endsWith('/')
        ? baseUrl.trimRight()
        : baseUrl.trimRight();
    _token = token;
  }

  String get _wsUrl => '$_baseUrl/webservice/rest/server.php';

  Future<Map<String, dynamic>?> _call(
      String function, Map<String, String> params) async {
    if (!isConfigured) return null;
    try {
      final uri = Uri.parse(_wsUrl).replace(queryParameters: {
        'wstoken': _token!,
        'moodlewsrestformat': 'json',
        'wsfunction': function,
        ...params,
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && data.containsKey('exception')) {
          debugPrint('Moodle error: ${data['message']}');
          return null;
        }
        return data is Map<String, dynamic> ? data : {'data': data};
      }
    } catch (e) {
      debugPrint('Moodle API error: $e');
    }
    return null;
  }

  // Get user info to validate token
  Future<Map<String, dynamic>?> getUserInfo() async {
    final result = await _call('core_webservice_get_site_info', {});
    return result;
  }

  // Get enrolled courses
  Future<List<Map<String, dynamic>>> getCourses(String userId) async {
    try {
      final uri = Uri.parse(_wsUrl).replace(queryParameters: {
        'wstoken': _token!,
        'moodlewsrestformat': 'json',
        'wsfunction': 'core_enrol_get_users_courses',
        'userid': userId,
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
      }
    } catch (e) {
      debugPrint('Error fetching courses: $e');
    }
    return [];
  }

  // Get assignments for a course
  Future<List<AssignmentModel>> getAssignmentsForCourse(
      String courseId, String courseName) async {
    try {
      final uri = Uri.parse(_wsUrl).replace(queryParameters: {
        'wstoken': _token!,
        'moodlewsrestformat': 'json',
        'wsfunction': 'mod_assign_get_assignments',
        'courseids[0]': courseId,
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>?;
        if (data != null && data['courses'] is List) {
          final courses = data['courses'] as List;
          if (courses.isNotEmpty) {
            final assignments = courses.first['assignments'] as List? ?? [];
            return assignments.map((a) {
              final assignMap = Map<String, dynamic>.from(a as Map);
              assignMap['courseName'] = courseName;
              return AssignmentModel.fromMoodle(assignMap);
            }).toList();
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching assignments: $e');
    }
    return [];
  }

  // Get all assignments across all enrolled courses
  Future<List<AssignmentModel>> getAllAssignments(String moodleUserId) async {
    final assignments = <AssignmentModel>[];
    try {
      final courses = await getCourses(moodleUserId);
      for (final course in courses) {
        final courseId = '${course['id']}';
        final courseName = course['fullname'] as String? ?? 'Course';
        final courseAssignments =
            await getAssignmentsForCourse(courseId, courseName);
        assignments.addAll(courseAssignments);
      }
    } catch (e) {
      debugPrint('Error fetching all assignments: $e');
    }
    return assignments;
  }

  // Get submission status for an assignment
  Future<Map<String, dynamic>?> getSubmissionStatus(
      String assignmentId, String userId) async {
    final uri = Uri.parse(_wsUrl).replace(queryParameters: {
      'wstoken': _token!,
      'moodlewsrestformat': 'json',
      'wsfunction': 'mod_assign_get_submission_status',
      'assignid': assignmentId,
      'userid': userId,
    });
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>?;
      }
    } catch (e) {
      debugPrint('Error fetching submission: $e');
    }
    return null;
  }

  // Validate Moodle credentials and return user info
  Future<Map<String, dynamic>?> validateCredentials(
      String url, String token) async {
    configure(url, token);
    return getUserInfo();
  }
}
