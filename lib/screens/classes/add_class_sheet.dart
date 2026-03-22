// lib/screens/classes/add_class_sheet.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../models/class_models.dart';
import '../../utils/app_theme.dart';

class AddClassSheet extends StatefulWidget {
  final UserModel user;
  final FirebaseFirestore db;
  final ClassModel? editClass; // null = create new
  const AddClassSheet(
      {super.key, required this.user, required this.db, this.editClass});

  @override
  State<AddClassSheet> createState() => _AddClassSheetState();
}

class _AddClassSheetState extends State<AddClassSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  // ── Details tab fields ──────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _shortnameCtrl = TextEditingController();
  DateTime? _startDate;
  int _colorValue = kClassColorOptions[0];
  String _gradingMode = 'complete';
  bool _gradebookSimple = false;
  bool _saving = false;

  bool get _isEdit => widget.editClass != null;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _isEdit ? 2 : 1, vsync: this);
    if (_isEdit) {
      final c = widget.editClass!;
      _nameCtrl.text = c.name;
      _shortnameCtrl.text = c.shortname;
      _startDate = c.startDate;
      _colorValue = c.colorValue;
      _gradingMode = c.gradingMode;
      _gradebookSimple = c.gradebookSimple;
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _nameCtrl.dispose();
    _shortnameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPad),
      child: Container(
        height: MediaQuery.of(context).size.height * (_isEdit ? 0.88 : 0.75),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(children: [
                Text(_isEdit ? 'Edit Class' : 'Add Class',
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ]),
            ),

            // ── Tabs (only in edit mode) ─────────────────────────
            if (_isEdit) ...[
              TabBar(
                controller: _tabCtrl,
                labelColor: AppTheme.classesColor,
                unselectedLabelColor: AppTheme.textSecondary,
                indicatorColor: AppTheme.classesColor,
                tabs: const [
                  Tab(icon: Icon(Icons.settings_outlined, size: 18), text: 'Details'),
                  Tab(icon: Icon(Icons.people_outlined, size: 18), text: 'People'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _DetailsTab(this),
                    _PeopleTab(
                      classModel: widget.editClass!,
                      db: widget.db,
                      currentUser: widget.user,
                    ),
                  ],
                ),
              ),
            ] else
              Expanded(child: _DetailsTab(this)),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('Please enter a class name', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final shortname = _shortnameCtrl.text.trim().isEmpty
          ? name
              .substring(0, name.length > 4 ? 4 : name.length)
              .toUpperCase()
          : _shortnameCtrl.text.trim().toUpperCase();

      if (_isEdit) {
        await widget.db
            .collection('classes')
            .doc(widget.editClass!.id)
            .update({
          'name': name,
          'shortname': shortname,
          'colorValue': _colorValue,
          'gradingMode': _gradingMode,
          'gradebookSimple': _gradebookSimple,
          if (_startDate != null) 'startDate': Timestamp.fromDate(_startDate!),
        });
      } else {
        final ref = widget.db.collection('classes').doc();
        final now = DateTime.now();
        await ref.set({
          'name': name,
          'shortname': shortname,
          'mentorUids': widget.user.canMentor ? [widget.user.uid] : [],
          'enrolledUids': [],
          'colorValue': _colorValue,
          'gradeLevel': '',
          'gradingMode': _gradingMode,
          'gradebookSimple': _gradebookSimple,
          'gradeA': 93.0,
          'gradeB': 85.0,
          'gradeC': 77.0,
          'gradeD': 70.0,
          'startDate':
              _startDate != null ? Timestamp.fromDate(_startDate!) : null,
          'schoolYearId': '${now.year}-${now.year + 1}',
          'isArchived': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        await _generateWeeks(ref.id);
      }
      if (mounted) Navigator.pop(context);
      if (mounted) _snack(_isEdit ? 'Class updated!' : 'Class created!');
    } catch (e) {
      _snack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _generateWeeks(String classId) async {
    try {
      final calSnap = await widget.db.collection('coopCalendar').get();
      if (calSnap.docs.isEmpty) return;
      final batch = widget.db.batch();
      int weekNum = 1;
      for (final doc in calSnap.docs) {
        DateTime monday;
        try {
          monday = DateFormat('yyyy-MM-dd').parse(doc.id);
        } catch (_) {
          continue;
        }
        final sunday = monday.add(const Duration(days: 6));
        final label = doc.data()['label'] as String? ?? '';
        final isBreak = label.toLowerCase().contains('break') ||
            label.toLowerCase().contains('holiday');
        final weekRef = widget.db
            .collection('classes')
            .doc(classId)
            .collection('weeks')
            .doc(doc.id);
        batch.set(weekRef, {
          'classId': classId,
          'weekNumber': weekNum++,
          'calendarLabel': label,
          'weekStart': Timestamp.fromDate(monday),
          'weekEnd': Timestamp.fromDate(sunday),
          'isBreak': isBreak,
          'isHidden': false,
          'autoRevealDate': null,
          'notes': '',
        });
      }
      await batch.commit();
    } catch (_) {}
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppTheme.error : AppTheme.success,
      behavior: SnackBarBehavior.floating,
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Details Tab
// ─────────────────────────────────────────────────────────────────────────────
class _DetailsTab extends StatelessWidget {
  final _AddClassSheetState s;
  const _DetailsTab(this.s);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: s._nameCtrl,
            decoration: const InputDecoration(
                labelText: 'Class Name *', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: s._shortnameCtrl,
            decoration: const InputDecoration(
                labelText: 'Short Name (e.g. PHY, ENG)',
                border: OutlineInputBorder()),
            maxLength: 8,
          ),
          const SizedBox(height: 4),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              s._startDate == null
                  ? 'Start Date (optional)'
                  : 'Start: ${DateFormat('MMM d, y').format(s._startDate!)}',
              style: const TextStyle(fontSize: 14),
            ),
            trailing: const Icon(Icons.calendar_today,
                size: 18, color: AppTheme.navy),
            onTap: () async {
              final p = await showDatePicker(
                context: context,
                initialDate: s._startDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (p != null) s.setState(() => s._startDate = p);
            },
          ),
          const Divider(),
          const Text('Class Color',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: kClassColorOptions.map((c) {
              final selected = c == s._colorValue;
              return GestureDetector(
                onTap: () => s.setState(() => s._colorValue = c),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Color(c),
                    shape: BoxShape.circle,
                    border: selected
                        ? Border.all(color: AppTheme.gold, width: 2.5)
                        : null,
                    boxShadow: selected
                        ? [
                            BoxShadow(
                                color: Color(c).withValues(alpha: 0.4),
                                blurRadius: 6)
                          ]
                        : null,
                  ),
                  child: selected
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          const Divider(),
          const Text('Default Grading Mode',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary)),
          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            title: const Text('Complete / Incomplete',
                style: TextStyle(fontSize: 13)),
            value: 'complete',
            groupValue: s._gradingMode,
            activeColor: AppTheme.classesColor,
            onChanged: (v) => s.setState(() => s._gradingMode = v!),
          ),
          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            title: const Text('Percentage (0–100%)',
                style: TextStyle(fontSize: 13)),
            value: 'percent',
            groupValue: s._gradingMode,
            activeColor: AppTheme.classesColor,
            onChanged: (v) => s.setState(() => s._gradingMode = v!),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Gradebook: show only Complete/Incomplete',
                style: TextStyle(fontSize: 13)),
            subtitle: const Text('Recommended for 6th grade and younger',
                style:
                    TextStyle(fontSize: 11, color: AppTheme.textHint)),
            value: s._gradebookSimple,
            activeColor: AppTheme.classesColor,
            onChanged: (v) => s.setState(() => s._gradebookSimple = v ?? false),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: s._saving ? null : s._save,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.classesColor,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: s._saving
                  ? const CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2)
                  : Text(s._isEdit ? 'Save Changes' : 'Create Class'),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// People Tab — add/remove mentors and students
// ─────────────────────────────────────────────────────────────────────────────
class _PeopleTab extends StatefulWidget {
  final ClassModel classModel;
  final FirebaseFirestore db;
  final UserModel currentUser;
  const _PeopleTab(
      {required this.classModel, required this.db, required this.currentUser});

  @override
  State<_PeopleTab> createState() => _PeopleTabState();
}

class _PeopleTabState extends State<_PeopleTab> {
  // Search controllers
  final _mentorSearchCtrl = TextEditingController();
  final _studentSearchCtrl = TextEditingController();
  String _mentorQuery = '';
  String _studentQuery = '';

  @override
  void initState() {
    super.initState();
    _mentorSearchCtrl.addListener(
        () => setState(() => _mentorQuery = _mentorSearchCtrl.text.toLowerCase()));
    _studentSearchCtrl.addListener(
        () => setState(() => _studentQuery = _studentSearchCtrl.text.toLowerCase()));
  }

  @override
  void dispose() {
    _mentorSearchCtrl.dispose();
    _studentSearchCtrl.dispose();
    super.dispose();
  }

  // ── Firestore helpers ──────────────────────────────────────────
  Future<void> _addMentor(String uid, String name) async {
    try {
      final batch = widget.db.batch();
      // Add to class mentorUids
      batch.update(widget.db.collection('classes').doc(widget.classModel.id), {
        'mentorUids': FieldValue.arrayUnion([uid]),
      });
      // Set isMentor + mentorClassIds on user
      batch.update(widget.db.collection('users').doc(uid), {
        'isMentor': true,
        'mentorClassIds': FieldValue.arrayUnion([widget.classModel.id]),
      });
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$name added as mentor'),
          backgroundColor: AppTheme.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.error,
        ));
      }
    }
  }

  Future<void> _removeMentor(String uid, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Mentor?'),
        content: Text('Remove $name as mentor of this class?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: Colors.white),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final batch = widget.db.batch();
      batch.update(widget.db.collection('classes').doc(widget.classModel.id), {
        'mentorUids': FieldValue.arrayRemove([uid]),
      });
      batch.update(widget.db.collection('users').doc(uid), {
        'mentorClassIds': FieldValue.arrayRemove([widget.classModel.id]),
      });
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$name removed'),
          backgroundColor: AppTheme.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.error,
        ));
      }
    }
  }

  Future<void> _toggleStudent(
      String uid, String name, bool currentlyEnrolled) async {
    try {
      await widget.db
          .collection('classes')
          .doc(widget.classModel.id)
          .update({
        'enrolledUids': currentlyEnrolled
            ? FieldValue.arrayRemove([uid])
            : FieldValue.arrayUnion([uid]),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(currentlyEnrolled
              ? '$name removed from class'
              : '$name enrolled in class'),
          backgroundColor:
              currentlyEnrolled ? AppTheme.warning : AppTheme.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.error,
        ));
      }
    }
  }

  void _showAddMentorSearch(
      List<String> currentMentorUids, List<String> enrolledUids) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UserSearchSheet(
        db: widget.db,
        title: 'Add Mentor',
        roleFilter: const ['mentor', 'admin', 'parent'],
        excludeUids: currentMentorUids,
        icon: Icons.person_pin_outlined,
        color: AppTheme.navy,
        onSelect: (uid, name) => _addMentor(uid, name),
      ),
    );
  }

  void _showAddStudentSearch(List<String> enrolledUids) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UserSearchSheet(
        db: widget.db,
        title: 'Add Student',
        roleFilter: const ['student'],
        excludeUids: enrolledUids,
        icon: Icons.school_outlined,
        color: AppTheme.classesColor,
        onSelect: (uid, name) => _toggleStudent(uid, name, false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: widget.db
          .collection('classes')
          .doc(widget.classModel.id)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snap.data!.data() as Map<String, dynamic>? ?? {};
        final mentorUids =
            List<String>.from(data['mentorUids'] as List? ?? []);
        final enrolledUids =
            List<String>.from(data['enrolledUids'] as List? ?? []);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Mentors section ──────────────────────────────
            _SectionHeader(
              title: 'Mentors',
              icon: Icons.person_pin_outlined,
              color: AppTheme.navy,
              count: mentorUids.length,
              onAdd: () => _showAddMentorSearch(mentorUids, enrolledUids),
            ),
            const SizedBox(height: 8),
            if (mentorUids.isEmpty)
              _EmptyPeople(
                message: 'No mentors assigned.\nTap + to add a mentor.',
                onAdd: () => _showAddMentorSearch(mentorUids, enrolledUids),
              )
            else
              ...mentorUids.map((uid) => _PersonTile(
                    uid: uid,
                    db: widget.db,
                    roleLabel: 'MENTOR',
                    roleColor: AppTheme.navy,
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: AppTheme.error, size: 20),
                      onPressed: () async {
                        final snap = await widget.db
                            .collection('users')
                            .doc(uid)
                            .get();
                        final name = (snap.data()?['displayName'] as String?) ??
                            'User';
                        if (mounted) _removeMentor(uid, name);
                      },
                    ),
                  )),

            const SizedBox(height: 20),

            // ── Students section ─────────────────────────────
            _SectionHeader(
              title: 'Enrolled Students',
              icon: Icons.school_outlined,
              color: AppTheme.classesColor,
              count: enrolledUids.length,
              onAdd: () => _showAddStudentSearch(enrolledUids),
            ),
            const SizedBox(height: 8),
            // Student search filter
            if (enrolledUids.isNotEmpty) ...[
              TextField(
                controller: _studentSearchCtrl,
                decoration: InputDecoration(
                  hintText: 'Filter enrolled students…',
                  prefixIcon: const Icon(Icons.search, size: 16),
                  isDense: true,
                  suffixIcon: _studentQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 14),
                          onPressed: () => _studentSearchCtrl.clear())
                      : null,
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (enrolledUids.isEmpty)
              _EmptyPeople(
                message: 'No students enrolled.\nTap + to add students.',
                onAdd: () => _showAddStudentSearch(enrolledUids),
              )
            else
              _StudentList(
                enrolledUids: enrolledUids,
                query: _studentQuery,
                db: widget.db,
                onRemove: (uid, name) => _toggleStudent(uid, name, true),
              ),
            const SizedBox(height: 30),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// User search bottom sheet — search all users by role and pick one
// ─────────────────────────────────────────────────────────────────────────────
class _UserSearchSheet extends StatefulWidget {
  final FirebaseFirestore db;
  final String title;
  final List<String> roleFilter;
  final List<String> excludeUids;
  final IconData icon;
  final Color color;
  final void Function(String uid, String name) onSelect;

  const _UserSearchSheet({
    required this.db,
    required this.title,
    required this.roleFilter,
    required this.excludeUids,
    required this.icon,
    required this.color,
    required this.onSelect,
  });

  @override
  State<_UserSearchSheet> createState() => _UserSearchSheetState();
}

class _UserSearchSheetState extends State<_UserSearchSheet> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() => _query = _ctrl.text.toLowerCase()));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(children: [
              Icon(widget.icon, color: widget.color, size: 20),
              const SizedBox(width: 8),
              Text(widget.title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context)),
            ]),
          ),
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search by name or email…',
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () => _ctrl.clear())
                    : null,
              ),
            ),
          ),
          const Divider(height: 1),
          // Results
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: widget.db
                  .collection('users')
                  .where('role', whereIn: widget.roleFilter)
                  .where('isActive', isEqualTo: true)
                  .snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                var docs = snap.data?.docs ?? [];

                // Exclude already-added users
                docs = docs
                    .where((d) => !widget.excludeUids.contains(d.id))
                    .toList();

                // Apply search filter
                if (_query.isNotEmpty) {
                  docs = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    final name = (data['displayName'] as String? ?? '')
                        .toLowerCase();
                    final email =
                        (data['email'] as String? ?? '').toLowerCase();
                    return name.contains(_query) || email.contains(_query);
                  }).toList();
                }

                // Sort alphabetically
                docs.sort((a, b) {
                  final an = (a.data() as Map)['displayName'] as String? ?? '';
                  final bn = (b.data() as Map)['displayName'] as String? ?? '';
                  return an.compareTo(bn);
                });

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(widget.icon,
                            size: 48, color: AppTheme.textHint),
                        const SizedBox(height: 12),
                        Text(
                          _query.isNotEmpty
                              ? 'No results for "$_query"'
                              : 'No eligible users found',
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 60),
                  itemBuilder: (_, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final uid = docs[i].id;
                    final name =
                        data['displayName'] as String? ?? 'Unknown';
                    final email = data['email'] as String? ?? '';
                    final role = data['role'] as String? ?? '';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            widget.color.withValues(alpha: 0.15),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: widget.color),
                        ),
                      ),
                      title: Text(name,
                          style: const TextStyle(fontSize: 14)),
                      subtitle: Text(
                        [
                          if (email.isNotEmpty) email,
                          role.toUpperCase(),
                        ].join(' · '),
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary),
                      ),
                      trailing: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onSelect(uid, name);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Add',
                            style: TextStyle(fontSize: 12)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final int count;
  final VoidCallback onAdd;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.color,
    required this.count,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 6),
      Text(title,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color)),
      const SizedBox(width: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('$count',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold, color: color)),
      ),
      const Spacer(),
      TextButton.icon(
        onPressed: onAdd,
        icon: Icon(Icons.add, size: 16, color: color),
        label: Text('Add', style: TextStyle(color: color, fontSize: 13)),
      ),
    ]);
  }
}

class _EmptyPeople extends StatelessWidget {
  final String message;
  final VoidCallback onAdd;
  const _EmptyPeople({required this.message, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAdd,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: AppTheme.cardBorder,
              style: BorderStyle.solid),
        ),
        child: Column(children: [
          const Icon(Icons.person_add_outlined,
              size: 32, color: AppTheme.textHint),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13)),
        ]),
      ),
    );
  }
}

/// Loads a single user's name from Firestore and renders a tile
class _PersonTile extends StatelessWidget {
  final String uid;
  final FirebaseFirestore db;
  final String roleLabel;
  final Color roleColor;
  final Widget trailing;

  const _PersonTile({
    required this.uid,
    required this.db,
    required this.roleLabel,
    required this.roleColor,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: db.collection('users').doc(uid).get(),
      builder: (ctx, snap) {
        final data =
            snap.data?.data() as Map<String, dynamic>? ?? {};
        final name = data['displayName'] as String? ?? uid;
        final email = data['email'] as String? ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: roleColor.withValues(alpha: 0.15),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: roleColor),
              ),
            ),
            title: Text(name,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500)),
            subtitle: Row(children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: roleColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(roleLabel,
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: roleColor)),
              ),
              if (email.isNotEmpty) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: Text(email,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary)),
                ),
              ],
            ]),
            trailing: snap.hasData ? trailing : const SizedBox(width: 20),
          ),
        );
      },
    );
  }
}

/// Loads enrolled student names and shows remove buttons
class _StudentList extends StatelessWidget {
  final List<String> enrolledUids;
  final String query;
  final FirebaseFirestore db;
  final void Function(String uid, String name) onRemove;

  const _StudentList({
    required this.enrolledUids,
    required this.query,
    required this.db,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, String>>>(
      future: _loadStudents(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Center(
              child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(),
          ));
        }
        var students = snap.data!;
        if (query.isNotEmpty) {
          students = students
              .where((s) =>
                  s['name']!.toLowerCase().contains(query) ||
                  s['email']!.toLowerCase().contains(query))
              .toList();
        }
        if (students.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text('No students match "$query"',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13)),
            ),
          );
        }
        return Column(
          children: students
              .map((s) => _PersonTile(
                    uid: s['uid']!,
                    db: db,
                    roleLabel: 'STUDENT',
                    roleColor: AppTheme.classesColor,
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: AppTheme.error, size: 20),
                      onPressed: () => onRemove(s['uid']!, s['name']!),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  Future<List<Map<String, String>>> _loadStudents() async {
    final futures = enrolledUids
        .map((uid) => db.collection('users').doc(uid).get())
        .toList();
    final docs = await Future.wait(futures);
    final result = <Map<String, String>>[];
    for (int i = 0; i < docs.length; i++) {
      final data = docs[i].data() as Map<String, dynamic>? ?? {};
      result.add({
        'uid': enrolledUids[i],
        'name': data['displayName'] as String? ?? enrolledUids[i],
        'email': data['email'] as String? ?? '',
      });
    }
    result.sort((a, b) => a['name']!.compareTo(b['name']!));
    return result;
  }
}
