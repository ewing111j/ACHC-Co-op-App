// lib/screens/classes/google_sheet_import_screen.dart
// Admin: Import class rosters from a Google Sheet.
// Each SHEET TAB = one class.  Columns: Last, First, DOB, Allergies, Grade, Email
// A row whose first cell starts with "Mentor" lists mentor names below.
// Features:
//   • Fetches all sheet tabs (via Sheets metadata API or manual tab entry)
//   • Editable class name per tab
//   • Checkbox: include this tab in import
//   • Creates Firestore class if it doesn't exist, enrolls students,
//     creates new student user documents for any unregistered students.
//   • Public sheet auto-export via /export?format=csv&gid=<gid>

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../../models/user_model.dart';
import '../../models/class_models.dart';
import '../../utils/app_theme.dart';

// ─── Data classes ─────────────────────────────────────────────────────────────

class _SheetTab {
  final String gid;       // Google Sheet tab id
  final String origName;  // Name read from the sheet
  String className;       // Editable display name for the class
  bool include;
  List<_ParsedStudent> students;
  List<String> mentorNames;

  _SheetTab({
    required this.gid,
    required this.origName,
    required this.className,
    this.include = true,
    List<_ParsedStudent>? students,
    List<String>? mentorNames,
  })  : students = students ?? [],
        mentorNames = mentorNames ?? [];
}

class _ParsedStudent {
  final String lastName;
  final String firstName;
  final String email;
  final String grade;
  _ParsedStudent({
    required this.lastName,
    required this.firstName,
    this.email = '',
    this.grade = '',
  });
  String get fullName => '$firstName $lastName'.trim();
}

// ─── Screen ───────────────────────────────────────────────────────────────────

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
  String? _statusMsg;
  bool _isError = false;
  List<_SheetTab> _tabs = [];
  bool _hasFetched = false;
  bool _importing = false;
  String _importLog = '';

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  // ── URL helpers ─────────────────────────────────────────────────────────────

  String? _extractSheetId(String input) {
    final re = RegExp(r'/spreadsheets/d/([a-zA-Z0-9_-]+)');
    final m = re.firstMatch(input);
    return m?.group(1);
  }

  String _csvUrl(String sheetId, String gid) =>
      'https://docs.google.com/spreadsheets/d/$sheetId/export?format=csv&gid=$gid';

  // ── Fetch sheet metadata (tab list) ─────────────────────────────────────────
  // Strategy 1: HTML scrape (works for public sheets, no API key needed)
  // Strategy 2: Feeds API v3 (older but sometimes works)
  // Strategy 3: Fallback to single tab with gid=0
  Future<List<Map<String, String>>> _fetchTabs(String sheetId) async {
    // --- Strategy 1: Scrape the sheet HTML for tab gids ---
    try {
      final htmlUrl = 'https://docs.google.com/spreadsheets/d/$sheetId/edit';
      final resp = await http.get(Uri.parse(htmlUrl), headers: {
        'User-Agent':
            'Mozilla/5.0 (compatible; ACHC-App/1.0)',
        'Accept': 'text/html',
      }).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        final html = resp.body;
        // The sheet HTML contains data like: ["Sheet1",null,0] or
        // a JSON blob with "sheets" metadata embedded in the page JS
        final tabs = _parseTabsFromHtml(html);
        if (tabs.isNotEmpty) return tabs;
      }
    } catch (_) {}

    // --- Strategy 2: Legacy Feeds API v3 ---
    try {
      final feedUrl =
          'https://spreadsheets.google.com/feeds/worksheets/$sheetId/public/basic?alt=json';
      final resp = await http
          .get(Uri.parse(feedUrl))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final jsonData = jsonDecode(resp.body) as Map<String, dynamic>;
        final entries =
            (jsonData['feed']?['entry'] as List<dynamic>?) ?? [];
        if (entries.isNotEmpty) {
          return entries.map<Map<String, String>>((e) {
            final title = e['title']?['\$t'] as String? ?? 'Sheet';
            final idStr = (e['id']?['\$t'] as String? ?? '');
            // v3 worksheet id ends in /od6, /obdx, etc — use order index as gid
            final gidMatch =
                RegExp(r'/([^/]+)$').firstMatch(idStr);
            final gid = gidMatch?.group(1) ?? '0';
            return {'name': title, 'gid': gid};
          }).toList();
        }
      }
    } catch (_) {}

    // --- Strategy 3: Fallback single tab ---
    return [];
  }

  /// Try to parse tab names + gids from the sheet's HTML
  List<Map<String, String>> _parseTabsFromHtml(String html) {
    final tabs = <Map<String, String>>[];
    // Google Sheets embeds something like:
    //   "sheets":[{"properties":{"sheetId":0,"title":"Sheet1","index":0,...}},...]
    // or in the bootstrapData variable (the exact key varies)
    try {
      final sheetsRe =
          RegExp(r'"sheetId"\s*:\s*(\d+)\s*,\s*"title"\s*:\s*"([^"]+)"');
      final matches = sheetsRe.allMatches(html).toList();
      for (final m in matches) {
        final gid = m.group(1) ?? '0';
        final name = m.group(2) ?? 'Sheet';
        tabs.add({'gid': gid, 'name': name});
      }
    } catch (_) {}
    return tabs;
  }

  // ── Parse a single CSV text into students + mentors ─────────────────────────
  _SheetTab _parseCsvIntoTab(
      String csv, String gid, String tabName) {
    final lines = csv
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final students = <_ParsedStudent>[];
    final mentors = <String>[];
    String className = tabName; // default; first non-header cell overrides

    bool seenMentorRow = false;
    bool seenHeader = false;

    for (final line in lines) {
      final cells = _splitCsvRow(line);
      if (cells.isEmpty) continue;
      final first = cells[0].trim();

      // Skip totally empty rows
      if (cells.every((c) => c.trim().isEmpty)) continue;

      // Header row (Last / First / …)
      if (!seenHeader &&
          (first.toLowerCase() == 'last' ||
              first.toLowerCase() == 'student' ||
              first.toLowerCase() == 'first name')) {
        seenHeader = true;
        continue;
      }

      // Mentor row: starts with "Mentor" or "Second"
      if (first.toLowerCase().startsWith('mentor') ||
          first.toLowerCase().startsWith('second')) {
        seenMentorRow = true;
        for (int i = 1; i < cells.length; i++) {
          final n = cells[i].trim();
          if (n.isNotEmpty) mentors.add(n);
        }
        continue;
      }

      // After mentor row, remaining cells may be additional mentor names
      if (seenMentorRow) {
        for (final c in cells) {
          final n = c.trim();
          if (n.isNotEmpty && !mentors.contains(n)) mentors.add(n);
        }
        continue;
      }

      // Student row: Last, First, DOB, Allergies, Grade, Email
      if (first.isNotEmpty && cells.length >= 2) {
        final last = first;
        final firstName = cells.length > 1 ? cells[1].trim() : '';
        final grade = cells.length > 4 ? cells[4].trim() : '';
        final email = cells.length > 5 ? cells[5].trim() : '';
        if (firstName.isNotEmpty || email.isNotEmpty) {
          students.add(_ParsedStudent(
            lastName: last,
            firstName: firstName,
            email: email,
            grade: grade,
          ));
        }
      }
    }

    return _SheetTab(
      gid: gid,
      origName: tabName,
      className: className,
      students: students,
      mentorNames: mentors,
    );
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

  // ── Main fetch ───────────────────────────────────────────────────────────────
  Future<void> _fetch() async {
    final raw = _urlCtrl.text.trim();
    final sheetId = _extractSheetId(raw);
    if (sheetId == null) {
      _setStatus('Paste the full Google Sheets URL (must contain /spreadsheets/d/…)',
          error: true);
      return;
    }
    setState(() {
      _loading = true;
      _statusMsg = 'Fetching sheet tabs…';
      _isError = false;
      _tabs = [];
      _hasFetched = false;
    });

    try {
      // 1. Get list of tabs (tries HTML scrape, then Feeds API)
      var tabMeta = await _fetchTabs(sheetId);

      // 2. If tab metadata empty, verify CSV access then fall back to single tab
      if (tabMeta.isEmpty) {
        final testUrl = _csvUrl(sheetId, '0');
        try {
          final testResp = await http
              .get(Uri.parse(testUrl))
              .timeout(const Duration(seconds: 10));
          if (testResp.statusCode == 200 && testResp.body.isNotEmpty) {
            tabMeta = [{'name': 'Sheet1', 'gid': '0'}];
          } else {
            _setStatus(
                '⚠️ Sheet is private or access is restricted.\n\n'
                'To fix:\n'
                '1. Open the sheet in Google Sheets\n'
                '2. File → Share → Share with others\n'
                '3. Change "Restricted" to "Anyone with the link"\n'
                '4. Set role to "Viewer"\n'
                '5. Click "Copy link" and paste it here.\n\n'
                'Then tap "Fetch Sheet Tabs" again.',
                error: true);
            return;
          }
        } catch (e) {
          _setStatus('Network error: $e', error: true);
          return;
        }
      }

      // 3. For each tab, fetch CSV and parse
      final result = <_SheetTab>[];
      for (final meta in tabMeta) {
        final gid = meta['gid']!;
        final name = meta['name']!;
        final url = _csvUrl(sheetId, gid);
        try {
          final resp = await http
              .get(Uri.parse(url))
              .timeout(const Duration(seconds: 10));
          if (resp.statusCode == 200 && resp.body.isNotEmpty) {
            final tab = _parseCsvIntoTab(resp.body, gid, name);
            result.add(tab);
          } else {
            result.add(_SheetTab(
                gid: gid,
                origName: name,
                className: name,
                include: false));
          }
        } catch (_) {
          result.add(_SheetTab(
              gid: gid, origName: name, className: name, include: false));
        }
      }

      setState(() {
        _tabs = result;
        _loading = false;
        _hasFetched = true;
        _statusMsg = result.isNotEmpty
            ? 'Found ${result.length} tab(s). '
                'Edit class names and uncheck any tabs to skip.'
            : 'No tabs found. Verify the sheet URL and sharing settings.';
      });
    } catch (e) {
      _setStatus(
          'Could not fetch the sheet.\n'
          'Make sure it is set to "Anyone with the link can view".\n'
          'Error: $e',
          error: true);
    }
  }

  // ── Import ───────────────────────────────────────────────────────────────────
  Future<void> _import() async {
    final included = _tabs.where((t) => t.include).toList();
    if (included.isEmpty) {
      _setStatus('Select at least one tab to import.', error: true);
      return;
    }
    setState(() {
      _importing = true;
      _importLog = '';
    });

    final uuid = const Uuid();
    final log = StringBuffer();

    for (final tab in included) {
      try {
        log.writeln('── ${tab.className} ──');

        // Find or create class in Firestore
        final classQuery = await _db
            .collection('classes')
            .where('name', isEqualTo: tab.className)
            .limit(1)
            .get();

        String classId;
        if (classQuery.docs.isNotEmpty) {
          classId = classQuery.docs.first.id;
          log.writeln('  Found existing class: $classId');
        } else {
          // Create new class
          final newClass = ClassModel(
            id: '',
            name: tab.className,
            shortname: tab.className.length > 8
                ? tab.className.substring(0, 8).trim()
                : tab.className,
            colorValue: kClassColorOptions[
                _tabs.indexOf(tab) % kClassColorOptions.length],
            gradingMode: 'complete',
            createdAt: DateTime.now(),
          );
          final ref = await _db.collection('classes').add(newClass.toMap());
          classId = ref.id;
          log.writeln('  Created class: $classId');
        }

        // Process students
        final enrolledUids = <String>[];
        for (final student in tab.students) {
          String? uid;

          // 1. Try email match
          if (student.email.isNotEmpty) {
            final snap = await _db
                .collection('users')
                .where('email', isEqualTo: student.email.toLowerCase())
                .limit(1)
                .get();
            if (snap.docs.isNotEmpty) uid = snap.docs.first.id;
          }

          // 2. Try name match
          if (uid == null && student.fullName.isNotEmpty) {
            final snap = await _db
                .collection('users')
                .where('displayName', isEqualTo: student.fullName)
                .where('role', isEqualTo: 'student')
                .limit(1)
                .get();
            if (snap.docs.isNotEmpty) uid = snap.docs.first.id;
          }

          // 3. Create new user if not found
          if (uid == null) {
            uid = uuid.v4();
            await _db.collection('users').doc(uid).set({
              'uid': uid,
              'displayName': student.fullName,
              'email': student.email.isNotEmpty
                  ? student.email.toLowerCase()
                  : '',
              'role': 'student',
              'isMentor': false,
              'mentorClassIds': [],
              'kidUids': [],
              'isActive': true,
              'grade': student.grade,
              'lastName': student.lastName,
              'firstName': student.firstName,
              'needsClaim': true,  // flag for parent claim flow
              'createdAt': FieldValue.serverTimestamp(),
            });
            log.writeln('    Created user: ${student.fullName}');
          } else {
            log.writeln('    Matched user: ${student.fullName} ($uid)');
          }

          enrolledUids.add(uid);
        }

        // Enroll all students in class
        if (enrolledUids.isNotEmpty) {
          await _db.collection('classes').doc(classId).update({
            'enrolledUids': FieldValue.arrayUnion(enrolledUids),
          });
          log.writeln(
              '  Enrolled ${enrolledUids.length} student(s)');
        }

        // Assign mentor UIDs
        for (final mentorName in tab.mentorNames) {
          final mSnap = await _db
              .collection('users')
              .where('displayName', isEqualTo: mentorName)
              .limit(1)
              .get();
          if (mSnap.docs.isNotEmpty) {
            final mUid = mSnap.docs.first.id;
            await _db.collection('classes').doc(classId).update({
              'mentorUids': FieldValue.arrayUnion([mUid]),
            });
            // Also set isMentor flag on user
            await _db.collection('users').doc(mUid).update({
              'isMentor': true,
              'mentorClassIds': FieldValue.arrayUnion([classId]),
            });
            log.writeln('  Assigned mentor: $mentorName');
          } else {
            log.writeln('  ⚠ Mentor not found: $mentorName');
          }
        }
        log.writeln('  ✓ Done');
      } catch (e) {
        log.writeln('  ✗ ERROR: $e');
      }
    }

    setState(() {
      _importing = false;
      _importLog = log.toString();
      _statusMsg = '✅ Import complete! See log below.';
      _isError = false;
    });
  }

  void _setStatus(String msg, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _importing = false;
      _statusMsg = msg;
      _isError = error;
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────────
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
        padding: const EdgeInsets.all(16),
        children: [
          // ── Instructions card ──────────────────────────────────
          _InfoCard(),
          const SizedBox(height: 14),

          // ── URL input ──────────────────────────────────────────
          TextField(
            controller: _urlCtrl,
            decoration: const InputDecoration(
              labelText: 'Google Sheet URL',
              prefixIcon: Icon(Icons.link, size: 18),
              hintText: 'https://docs.google.com/spreadsheets/d/…',
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading || _importing ? null : _fetch,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.cloud_download_outlined),
              label: const Text('Fetch Sheet Tabs'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ),

          // ── Status ────────────────────────────────────────────
          if (_statusMsg != null) ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: (_isError ? AppTheme.error : AppTheme.success)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: (_isError ? AppTheme.error : AppTheme.success)
                        .withValues(alpha: 0.3)),
              ),
              child: Text(_statusMsg!,
                  style: TextStyle(
                      fontSize: 12,
                      color:
                          _isError ? AppTheme.error : AppTheme.success)),
            ),
          ],

          // ── Tab list ──────────────────────────────────────────
          if (_hasFetched && _tabs.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text('Sheet Tabs',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.navy)),
                ),
                TextButton.icon(
                  onPressed: () => setState(() {
                    for (final t in _tabs) t.include = true;
                  }),
                  icon: const Icon(Icons.select_all, size: 16),
                  label: const Text('All', style: TextStyle(fontSize: 12)),
                ),
                TextButton.icon(
                  onPressed: () => setState(() {
                    for (final t in _tabs) t.include = false;
                  }),
                  icon: const Icon(Icons.deselect, size: 16),
                  label: const Text('None', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._tabs.asMap().entries.map((entry) {
              final i = entry.key;
              final tab = entry.value;
              return _TabCard(
                tab: tab,
                onIncludeChanged: (v) =>
                    setState(() => _tabs[i].include = v),
                onNameChanged: (v) =>
                    setState(() => _tabs[i].className = v),
              );
            }),
            const SizedBox(height: 16),

            // ── Import button ──────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _importing ? null : _import,
                icon: _importing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.upload_outlined),
                label: Text(_importing ? 'Importing…' : 'Import Selected Tabs'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.classesColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13)),
              ),
            ),
          ],

          // ── Import log ────────────────────────────────────────
          if (_importLog.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Import Log',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.navy)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8)),
              child: Text(_importLog,
                  style: const TextStyle(
                      fontSize: 11,
                      color: Colors.greenAccent,
                      fontFamily: 'monospace')),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ─── Tab Card widget ──────────────────────────────────────────────────────────
class _TabCard extends StatefulWidget {
  final _SheetTab tab;
  final ValueChanged<bool> onIncludeChanged;
  final ValueChanged<String> onNameChanged;
  const _TabCard({
    required this.tab,
    required this.onIncludeChanged,
    required this.onNameChanged,
  });

  @override
  State<_TabCard> createState() => _TabCardState();
}

class _TabCardState extends State<_TabCard> {
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.tab.className);
    _nameCtrl.addListener(() => widget.onNameChanged(_nameCtrl.text));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tab = widget.tab;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: tab.include
                ? AppTheme.classesColor.withValues(alpha: 0.5)
                : AppTheme.cardBorder),
      ),
      child: ExpansionTile(
        leading: Checkbox(
          value: tab.include,
          activeColor: AppTheme.classesColor,
          onChanged: (v) => widget.onIncludeChanged(v ?? false),
        ),
        title: TextField(
          controller: _nameCtrl,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 0),
            border: InputBorder.none,
            hintText: 'Class name',
          ),
        ),
        subtitle: Text(
          '${tab.students.length} students · ${tab.mentorNames.length} mentor(s)'
          ' · tab: ${tab.origName}',
          style: const TextStyle(
              fontSize: 11, color: AppTheme.textSecondary),
        ),
        children: [
          if (tab.mentorNames.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Row(
                children: [
                  const Icon(Icons.person_pin,
                      size: 14, color: AppTheme.navy),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                        'Mentors: ${tab.mentorNames.join(', ')}',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.navy)),
                  ),
                ],
              ),
            ),
          ...tab.students.map(
            (s) => ListTile(
              dense: true,
              leading: const Icon(Icons.person_outline,
                  size: 16, color: AppTheme.textSecondary),
              title: Text(s.fullName,
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
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

// ─── Info card ────────────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.navy.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.info_outline, size: 16, color: AppTheme.navy),
            SizedBox(width: 6),
            Text('Sheet Format',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppTheme.navy)),
          ]),
          const SizedBox(height: 8),
          const Text(
            '• Each sheet tab = one class\n'
            '• Columns: Last, First, DOB, Allergies, Grade, Email\n'
            '• A row starting with "Mentor" lists mentor names\n'
            '• Share the sheet as "Anyone with the link can view"\n'
            '• New students are created automatically as users\n'
            '• Existing users matched by email or full name',
            style: TextStyle(
                fontSize: 12, color: AppTheme.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () {},
            child: const Text(
              'Troubleshooting: If fetch fails, ensure the sheet is public\n'
              '(File → Share → Anyone with the link → Viewer)',
              style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textTertiary,
                  fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }
}
