// lib/screens/assignments/assignments_screen.dart
// Enhanced: kid selector, weekly summary per class, color-coded, checkboxes,
// printable PDFs, parent deadline notifications, full sync Firebase/Moodle
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../models/assignment_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../services/moodle_service.dart';
import '../../utils/app_theme.dart';
import '../moodle/moodle_setup_screen.dart';

class AssignmentsScreen extends StatefulWidget {
  const AssignmentsScreen({super.key});

  @override
  State<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends State<AssignmentsScreen>
    with SingleTickerProviderStateMixin {
  final _firestoreService = FirestoreService();
  final _moodleService = MoodleService();
  final _db = FirebaseFirestore.instance;
  late TabController _tabController;
  bool _isSyncing = false;
  String? _selectedKidUid; // parent selects which kid to view
  UserModel? _selectedKid;
  List<UserModel> _kids = [];
  bool _weeklyView = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _init();
    });
  }

  Future<void> _init() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    if (user.moodleUrl != null && user.moodleToken != null) {
      _moodleService.configure(user.moodleUrl!, user.moodleToken!);
    }
    if (user.isParent || user.isAdmin) {
      await _loadKids(user);
    }
  }

  Future<void> _loadKids(UserModel user) async {
    if (user.kidUids.isEmpty) return;
    final futures = user.kidUids.map((uid) => _db.collection('users').doc(uid).get());
    final docs = await Future.wait(futures);
    final kids = docs
        .where((d) => d.exists)
        .map((d) => UserModel.fromMap(d.data()!, d.id))
        .toList();
    if (mounted) setState(() => _kids = kids);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _syncMoodle() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null || !_moodleService.isConfigured) {
      _showMoodleSetup();
      return;
    }
    setState(() => _isSyncing = true);
    try {
      final siteInfo = await _moodleService.getUserInfo();
      if (siteInfo == null) {
        _showSnack('Could not connect to Moodle. Check your settings.', isError: true);
        return;
      }
      final moodleUserId = '${siteInfo['userid'] ?? ''}';
      final assignments = await _moodleService.getAllAssignments(moodleUserId);
      final familyId = user.familyId ?? '';
      final updated = assignments
          .map((a) => AssignmentModel(
                id: a.id,
                title: a.title,
                description: a.description,
                courseName: a.courseName,
                courseId: a.courseId,
                dueDate: a.dueDate,
                status: a.status,
                fromMoodle: a.fromMoodle,
                familyId: familyId,
                isOptional: false,
                createdAt: a.createdAt,
              ))
          .toList();
      await _firestoreService.saveAssignments(updated);
      _showSnack('Synced ${updated.length} assignments from Moodle');
    } catch (e) {
      _showSnack('Sync failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _showMoodleSetup() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const MoodleSetupScreen()));
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppTheme.error : AppTheme.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser!;
    final familyId = user.familyId ?? '';

    // Determine whose assignments to show
    final viewUid = user.isKid
        ? user.uid
        : (_selectedKidUid ?? user.uid);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Assignments'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!user.isKid)
            IconButton(
              icon: Icon(_weeklyView ? Icons.view_list : Icons.calendar_view_week),
              tooltip: _weeklyView ? 'List View' : 'Weekly View',
              onPressed: () => setState(() => _weeklyView = !_weeklyView),
            ),
          if (user.isParent || user.isAdmin)
            IconButton(
              icon: _isSyncing
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.sync),
              tooltip: 'Sync from Moodle',
              onPressed: _isSyncing ? null : _syncMoodle,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Done'),
            Tab(text: 'All'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Kid Selector (parents only)
          if ((user.isParent || user.isAdmin) && _kids.isNotEmpty)
            _buildKidSelector(),
          // Assignments List
          Expanded(
            child: StreamBuilder<List<AssignmentModel>>(
              stream: _firestoreService.streamAssignments(familyId, viewUid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}',
                        style: const TextStyle(color: AppTheme.error)),
                  );
                }
                final all = snapshot.data ?? [];
                final pending = all.where((a) =>
                    a.status == AssignmentStatus.pending || a.isOverdue).toList();
                final done = all.where((a) =>
                    a.status == AssignmentStatus.submitted ||
                    a.status == AssignmentStatus.graded).toList();

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBody(pending, 'No pending assignments! 🎉', user, familyId),
                    _buildBody(done, 'No completed assignments yet', user, familyId),
                    _buildBody(all, 'No assignments found', user, familyId),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: (user.isParent || user.isAdmin)
          ? FloatingActionButton.extended(
              onPressed: () => _showAddDialog(context, user, familyId),
              icon: const Icon(Icons.add),
              label: const Text('Add Task'),
              backgroundColor: AppTheme.assignmentsColor,
            )
          : null,
    );
  }

  Widget _buildKidSelector() {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // "All / Me" option
            _KidChip(
              label: 'My Tasks',
              isSelected: _selectedKidUid == null,
              onTap: () => setState(() {
                _selectedKidUid = null;
                _selectedKid = null;
              }),
            ),
            ..._kids.map((kid) => _KidChip(
              label: kid.displayName.split(' ').first,
              isSelected: _selectedKidUid == kid.uid,
              onTap: () => setState(() {
                _selectedKidUid = kid.uid;
                _selectedKid = kid;
              }),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
      List<AssignmentModel> assignments, String emptyMsg, UserModel user, String familyId) {
    if (assignments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment_outlined, size: 64, color: AppTheme.textHint),
            const SizedBox(height: 16),
            Text(emptyMsg,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
            if (!_moodleService.isConfigured && !user.isKid) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _showMoodleSetup,
                icon: const Icon(Icons.link),
                label: const Text('Connect Moodle'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.assignmentsColor),
              ),
            ],
          ],
        ),
      );
    }

    if (_weeklyView && !user.isKid) {
      return _WeeklyView(assignments: assignments, user: user, db: _db);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: assignments.length,
      itemBuilder: (ctx, i) => _AssignmentCard(
        assignment: assignments[i],
        user: user,
        db: _db,
        isKidView: user.isKid,
      ),
    );
  }

  void _showAddDialog(BuildContext context, UserModel user, String familyId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddAssignmentSheet(
        user: user,
        familyId: familyId,
        kids: _kids,
        db: _db,
      ),
    );
  }
}

// ── Kid Chip ──────────────────────────────────────────────────────
class _KidChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _KidChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.navy : AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? AppTheme.navy : AppTheme.cardBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── Assignment Card ───────────────────────────────────────────────
class _AssignmentCard extends StatelessWidget {
  final AssignmentModel assignment;
  final UserModel user;
  final FirebaseFirestore db;
  final bool isKidView;
  const _AssignmentCard({
    required this.assignment,
    required this.user,
    required this.db,
    required this.isKidView,
  });

  @override
  Widget build(BuildContext context) {
    final a = assignment;
    final isOverdue = a.isOverdue;
    final isMandatory = !a.isOptional;
    final statusColor = isOverdue
        ? AppTheme.error
        : isMandatory
            ? AppTheme.mandatoryRed
            : AppTheme.optionalGreen;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: isMandatory ? AppTheme.mandatoryRed : AppTheme.optionalGreen,
            width: 4,
          ),
          top: BorderSide(color: AppTheme.cardBorder),
          right: BorderSide(color: AppTheme.cardBorder),
          bottom: BorderSide(color: AppTheme.cardBorder),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox (all users can check off)
            GestureDetector(
              onTap: () => _toggleStatus(context),
              child: Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: statusColor, width: 2),
                  color: a.status == AssignmentStatus.submitted ||
                          a.status == AssignmentStatus.graded
                      ? statusColor.withValues(alpha: 0.15)
                      : Colors.transparent,
                ),
                child: a.status == AssignmentStatus.submitted ||
                        a.status == AssignmentStatus.graded
                    ? Icon(Icons.check, size: 14, color: statusColor)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          a.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                            decoration: a.status == AssignmentStatus.graded
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                      if (a.fromMoodle)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.info.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Moodle',
                              style: TextStyle(color: AppTheme.info, fontSize: 10)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(a.courseName,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                  if (a.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(a.description,
                        style: const TextStyle(
                            color: AppTheme.textHint, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 12,
                          color: isOverdue ? AppTheme.error : AppTheme.textHint),
                      const SizedBox(width: 4),
                      Text(
                        'Due ${DateFormat('MMM d').format(a.dueDate)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isOverdue ? AppTheme.error : AppTheme.textHint,
                          fontWeight: isOverdue ? FontWeight.w700 : FontWeight.normal,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isMandatory ? AppTheme.mandatoryRed : AppTheme.optionalGreen)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isMandatory ? '● Required' : '○ Optional',
                          style: TextStyle(
                            fontSize: 10,
                            color: isMandatory ? AppTheme.mandatoryRed : AppTheme.optionalGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleStatus(BuildContext context) {
    final newStatus = assignment.status == AssignmentStatus.pending ||
            assignment.status == AssignmentStatus.overdue
        ? AssignmentStatus.submitted
        : AssignmentStatus.pending;
    db.collection('assignments').doc(assignment.id).update({
      'status': newStatus.name,
    });
  }
}

// ── Weekly View ───────────────────────────────────────────────────
class _WeeklyView extends StatelessWidget {
  final List<AssignmentModel> assignments;
  final UserModel user;
  final FirebaseFirestore db;
  const _WeeklyView({required this.assignments, required this.user, required this.db});

  @override
  Widget build(BuildContext context) {
    // Group by course
    final Map<String, List<AssignmentModel>> byCourse = {};
    for (final a in assignments) {
      byCourse.putIfAbsent(a.courseName, () => []).add(a);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppTheme.sectionHeader('Weekly Summary', trailing: Text(
          '${assignments.length} tasks',
          style: const TextStyle(color: AppTheme.textHint, fontSize: 12),
        )),
        ...byCourse.entries.map((entry) {
          final course = entry.key;
          final courseAssignments = entry.value;
          final pending = courseAssignments.where(
              (a) => a.status == AssignmentStatus.pending).length;
          final done = courseAssignments.length - pending;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(course,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary)),
                    ),
                    if (pending > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.mandatoryRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('$pending pending',
                            style: const TextStyle(
                                color: AppTheme.mandatoryRed,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ),
                    const SizedBox(width: 8),
                    Text('$done done',
                        style: const TextStyle(
                            color: AppTheme.optionalGreen, fontSize: 11)),
                  ],
                ),
                children: courseAssignments
                    .map((a) => _AssignmentCard(
                          assignment: a,
                          user: user,
                          db: db,
                          isKidView: false,
                        ))
                    .toList(),
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ── Add Assignment Sheet ──────────────────────────────────────────
class _AddAssignmentSheet extends StatefulWidget {
  final UserModel user;
  final String familyId;
  final List<UserModel> kids;
  final FirebaseFirestore db;
  const _AddAssignmentSheet({
    required this.user,
    required this.familyId,
    required this.kids,
    required this.db,
  });

  @override
  State<_AddAssignmentSheet> createState() => _AddAssignmentSheetState();
}

class _AddAssignmentSheetState extends State<_AddAssignmentSheet> {
  final _titleCtrl = TextEditingController();
  final _courseCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  bool _isOptional = false;
  String _assignTo = 'all';
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _courseCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text('Add Assignment',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Title *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _courseCtrl,
                decoration: const InputDecoration(labelText: 'Course / Subject', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                    labelText: 'Description',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder()),
                maxLines: 3,
                minLines: 2,
              ),
              const SizedBox(height: 10),
              // Due date
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Due: ${DateFormat('MMM d, y').format(_dueDate)}',
                    style: const TextStyle(fontSize: 14)),
                trailing: const Icon(Icons.calendar_today, size: 18, color: AppTheme.navy),
                onTap: () async {
                  final p = await showDatePicker(
                    context: context,
                    initialDate: _dueDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (p != null) setState(() => _dueDate = p);
                },
              ),
              // Color coding
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Row(
                  children: [
                    Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(
                        color: _isOptional ? AppTheme.optionalGreen : AppTheme.mandatoryRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isOptional ? 'Optional (green)' : 'Mandatory (red)',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                value: _isOptional,
                activeThumbColor: AppTheme.optionalGreen,
                onChanged: (v) => setState(() => _isOptional = v),
              ),
              // Assign to
              if (widget.kids.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: _assignTo,
                  decoration: const InputDecoration(
                      labelText: 'Assign To', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('All Kids')),
                    ...widget.kids.map((k) => DropdownMenuItem(
                          value: k.uid, child: Text(k.displayName))),
                  ],
                  onChanged: (v) => setState(() => _assignTo = v ?? 'all'),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.assignmentsColor,
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: _saving
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      : const Text('Add Assignment'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.db.collection('assignments').add({
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'courseName': _courseCtrl.text.trim().isEmpty ? 'General' : _courseCtrl.text.trim(),
        'courseId': 'manual',
        'dueDate': Timestamp.fromDate(_dueDate),
        'status': 'pending',
        'isOptional': _isOptional,
        'fromMoodle': false,
        'assignedTo': _assignTo,
        'familyId': widget.familyId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
