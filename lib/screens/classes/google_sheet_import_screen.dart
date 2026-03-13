// lib/screens/classes/google_sheet_import_screen.dart
// Admin-only: import class enrollment from a shared Google Sheet
// Sheet format: Row 1 = Class Name; columns = Last, First, DOB, Allergies, Grade, Email
// Mentor assignments listed below the student list with a label row

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../../models/user_model.dart';
import '../../utils/app_theme.dart';

class GoogleSheetImportScreen extends StatefulWidget {
  final UserModel user;
  const GoogleSheetImportScreen({super.key, required this.user});

  @override
  State<GoogleSheetImportScreen> createState() =>
      _GoogleSheetImportScreenState();
}

class _GoogleSheetImportScreenState extends State<GoogleSheetImportScreen> {
  final _db = FirebaseFirestore.instance;
  final _urlCtrl = TextEditingController();
  bool _loading = false;
  String? _status;
  List<_ParsedClass> _preview = [];
  bool _showPreview = false;

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  // Convert Google Sheets URL → CSV export URL
  String? _toCsvUrl(String input) {
    // Support both share URL and direct /d/ID forms
    final re = RegExp(r'/spreadsheets/d/([a-zA-Z0-9_-]+)');
    final m = re.firstMatch(input);
    if (m == null) return null;
    final id = m.group(1)!;
    return 'https://docs.google.com/spreadsheets/d/$id/export?format=csv&gid=0';
  }

  Future<void> _fetchAndParse() async {
    final rawUrl = _urlCtrl.text.trim();
    if (rawUrl.isEmpty) {
      _setStatus('Please enter a Google Sheet URL', error: true);
      return;
    }
    final csvUrl = _toCsvUrl(rawUrl);
    if (csvUrl == null) {
      _setStatus(
          'Invalid URL. Paste the full Google Sheets share link.', error: true);
      return;
    }
    setState(() {
      _loading = true;
      _status = 'Fetching sheet…';
      _showPreview = false;
      _preview = [];
    });
    try {
      final resp = await http.get(Uri.parse(csvUrl));
      if (resp.statusCode != 200) {
        _setStatus(
            'Could not fetch sheet (status ${resp.statusCode}). Make sure it is public.',
            error: true);
        return;
      }
      final parsed = _parseCsv(resp.body);
      setState(() {
        _preview = parsed;
        _showPreview = true;
        _loading = false;
        _status =
            'Found ${parsed.length} class(es). Review below, then tap Import.';
      });
    } catch (e) {
      _setStatus('Error: $e', error: true);
    }
  }

  // Parse CSV into class records
  // Format: Row 1 = class name in first cell
  //         Subsequent rows: student data (Last, First, DOB, Allergies, Grade, Email)
  //         A row starting with "Mentor:" = mentor list
  List<_ParsedClass> _parseCsv(String csv) {
    final lines = csv.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final classes = <_ParsedClass>[];
    _ParsedClass? current;

    for (final line in lines) {
      final cells = _splitCsvRow(line);
      if (cells.isEmpty) continue;
      final first = cells[0].trim();

      // Detect class header: only 1 non-empty cell OR cell[1] is empty and first != header keywords
      final isClassHeader = cells.where((c) => c.trim().isNotEmpty).length == 1 &&
          first.isNotEmpty &&
          !first.toLowerCase().startsWith('last') &&
          !first.toLowerCase().startsWith('student') &&
          !first.toLowerCase().startsWith('mentor');

      if (isClassHeader) {
        current = _ParsedClass(name: first);
        classes.add(current);
        continue;
      }

      if (current == null) continue;

      // Skip header row (Last / First / DOB…)
      if (first.toLowerCase() == 'last' || first.toLowerCase() == 'student') {
        continue;
      }

      // Mentor row
      if (first.toLowerCase().startsWith('mentor')) {
        // Remaining cells are mentor names/emails
        for (int i = 1; i < cells.length; i++) {
          final name = cells[i].trim();
          if (name.isNotEmpty) current.mentors.add(name);
        }
        continue;
      }

      // Student row: Last, First, DOB, Allergies, Grade, Email
      if (first.isNotEmpty && cells.length >= 2) {
        final last = first;
        final firstName = cells.length > 1 ? cells[1].trim() : '';
        final email = cells.length > 5 ? cells[5].trim() : '';
        final grade = cells.length > 4 ? cells[4].trim() : '';
        current.students.add(_ParsedStudent(
          lastName: last,
          firstName: firstName,
          email: email,
          grade: grade,
        ));
      }
    }
    return classes;
  }

  List<String> _splitCsvRow(String row) {
    final cells = <String>[];
    final buf = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < row.length; i++) {
      final c = row[i];
      if (c == '"') {
        inQuotes = !inQuotes;
      } else if (c == ',' && !inQuotes) {
        cells.add(buf.toString());
        buf.clear();
      } else {
        buf.write(c);
      }
    }
    cells.add(buf.toString());
    return cells;
  }

  Future<void> _import() async {
    if (_preview.isEmpty) return;
    setState(() {
      _loading = true;
      _status = 'Importing…';
    });
    try {
      int classesUpdated = 0;
      int studentsLinked = 0;

      for (final cls in _preview) {
        // Find or create class by name (case-insensitive)
        final nameNorm = cls.name.trim().toLowerCase();
        final existSnap = await _db.collection('classes').get();
        final existing = existSnap.docs.firstWhere(
          (d) => (d.data()['name'] as String? ?? '').toLowerCase() == nameNorm,
          orElse: () => throw 'Class "${cls.name}" not found in Firestore. Create it first.',
        );
        final classId = existing.id;
        final enrolledUids = <String>[];

        for (final student in cls.students) {
          if (student.email.isNotEmpty) {
            // Look up user by email
            final userSnap = await _db
                .collection('users')
                .where('email', isEqualTo: student.email)
                .limit(1)
                .get();
            if (userSnap.docs.isNotEmpty) {
              final uid = userSnap.docs.first.id;
              enrolledUids.add(uid);
              studentsLinked++;
            }
          }
        }

        // Bulk update enrolledUids (union)
        if (enrolledUids.isNotEmpty) {
          await _db.collection('classes').doc(classId).update({
            'enrolledUids': FieldValue.arrayUnion(enrolledUids),
          });
        }

        // Link mentor UIDs
        final mentorUids = <String>[];
        for (final mentorName in cls.mentors) {
          final mSnap = await _db
              .collection('users')
              .where('displayName', isEqualTo: mentorName)
              .limit(1)
              .get();
          if (mSnap.docs.isNotEmpty) {
            mentorUids.add(mSnap.docs.first.id);
          }
        }
        if (mentorUids.isNotEmpty) {
          await _db.collection('classes').doc(classId).update({
            'mentorUids': FieldValue.arrayUnion(mentorUids),
          });
        }
        classesUpdated++;
      }
      setState(() {
        _loading = false;
        _status =
            '✅ Import complete! $classesUpdated class(es) updated, $studentsLinked student(s) enrolled.';
        _showPreview = false;
        _preview = [];
      });
    } catch (e) {
      _setStatus('Import error: $e', error: true);
    }
  }

  void _setStatus(String msg, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _status = error ? '⚠️ $msg' : msg;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Import from Google Sheet'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Instructions
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.navy.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sheet Format',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.navy)),
                SizedBox(height: 8),
                Text(
                  '• Row 1: Class name (single cell)\n'
                  '• Next rows: Last, First, DOB, Allergies, Grade, Email\n'
                  '• A row beginning with "Mentor:" lists mentor names\n'
                  '• Repeat for each class in the sheet\n'
                  '• Sheet must be publicly accessible (View link)',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // URL field
          TextField(
            controller: _urlCtrl,
            decoration: const InputDecoration(
              labelText: 'Google Sheet Share URL',
              prefixIcon: Icon(Icons.link, size: 18),
              hintText: 'https://docs.google.com/spreadsheets/d/...',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _fetchAndParse,
                  icon: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.refresh),
                  label: const Text('Fetch & Preview'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.navy,
                      foregroundColor: Colors.white),
                ),
              ),
            ],
          ),
          if (_status != null) ...[
            const SizedBox(height: 12),
            Text(_status!,
                style: TextStyle(
                    fontSize: 13,
                    color: _status!.startsWith('⚠️')
                        ? AppTheme.error
                        : _status!.startsWith('✅')
                            ? AppTheme.success
                            : AppTheme.textSecondary)),
          ],
          // Preview
          if (_showPreview && _preview.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                const Text('Preview',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navy)),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _loading ? null : _import,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text('Import to Firestore'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.classesColor,
                      foregroundColor: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ..._preview.map((cls) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: ExpansionTile(
                    title: Text(cls.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(
                        '${cls.students.length} students · ${cls.mentors.length} mentor(s)',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary)),
                    children: [
                      if (cls.mentors.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.person_pin_outlined,
                                  size: 14, color: AppTheme.navy),
                              const SizedBox(width: 6),
                              Text('Mentors: ${cls.mentors.join(', ')}',
                                  style: const TextStyle(
                                      fontSize: 12, color: AppTheme.navy)),
                            ],
                          ),
                        ),
                      ...cls.students.map((s) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.person_outline,
                                size: 16, color: AppTheme.textSecondary),
                            title: Text('${s.firstName} ${s.lastName}',
                                style: const TextStyle(fontSize: 13)),
                            subtitle: s.email.isNotEmpty
                                ? Text(s.email,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textTertiary))
                                : null,
                            trailing: s.grade.isNotEmpty
                                ? Text('Gr. ${s.grade}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textSecondary))
                                : null,
                          )),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

// ── Data Models ───────────────────────────────────────────────────────────────

class _ParsedClass {
  final String name;
  final List<_ParsedStudent> students = [];
  final List<String> mentors = [];
  _ParsedClass({required this.name});
}

class _ParsedStudent {
  final String lastName;
  final String firstName;
  final String email;
  final String grade;
  const _ParsedStudent({
    required this.lastName,
    required this.firstName,
    required this.email,
    required this.grade,
  });
}
