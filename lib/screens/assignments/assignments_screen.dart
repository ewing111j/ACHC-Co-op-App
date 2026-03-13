// lib/screens/assignments/assignments_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../models/assignment_model.dart';
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
  late TabController _tabController;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initMoodle();
  }

  void _initMoodle() {
    final user = context.read<AuthProvider>().currentUser;
    if (user?.moodleUrl != null && user?.moodleToken != null) {
      _moodleService.configure(user!.moodleUrl!, user.moodleToken!);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _syncMoodle() async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null || !_moodleService.isConfigured) {
      _showMoodleSetup();
      return;
    }

    setState(() => _isSyncing = true);
    try {
      final siteInfo = await _moodleService.getUserInfo();
      if (siteInfo == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not connect to Moodle. Check your settings.'),
              backgroundColor: AppTheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final moodleUserId = '${siteInfo['userid'] ?? ''}';
      final assignments =
          await _moodleService.getAllAssignments(moodleUserId);

      // Update familyId on all assignments
      final familyId = user.familyId ?? '';
      final updatedAssignments = assignments
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
                createdAt: a.createdAt,
              ))
          .toList();

      await _firestoreService.saveAssignments(updatedAssignments);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Synced ${updatedAssignments.length} assignments from Moodle'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _showMoodleSetup() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MoodleSetupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser!;
    final familyId = user.familyId ?? '';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Assignments'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (user.isParent || user.isAdmin)
            IconButton(
              icon: _isSyncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.sync),
              tooltip: 'Sync from Moodle',
              onPressed: _isSyncing ? null : _syncMoodle,
            ),
          if (!_moodleService.isConfigured && (user.isParent || user.isAdmin))
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Setup Moodle',
              onPressed: _showMoodleSetup,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Submitted'),
            Tab(text: 'All'),
          ],
        ),
      ),
      body: StreamBuilder<List<AssignmentModel>>(
        stream: _firestoreService.streamAssignments(familyId, user.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: AppTheme.error),
                  const SizedBox(height: 12),
                  Text('Error: ${snapshot.error}',
                      style: const TextStyle(color: AppTheme.error)),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final all = snapshot.data ?? [];
          final pending = all
              .where((a) =>
                  a.status == AssignmentStatus.pending || a.isOverdue)
              .toList();
          final submitted = all
              .where((a) =>
                  a.status == AssignmentStatus.submitted ||
                  a.status == AssignmentStatus.graded)
              .toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildAssignmentList(pending, 'No pending assignments! 🎉'),
              _buildAssignmentList(
                  submitted, 'No submitted assignments yet'),
              _buildAssignmentList(all, 'No assignments found'),
            ],
          );
        },
      ),
      floatingActionButton: (user.isParent || user.isAdmin)
          ? FloatingActionButton.extended(
              onPressed: () => _showAddAssignmentDialog(context, user.familyId ?? ''),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
              backgroundColor: AppTheme.assignmentsColor,
            )
          : null,
    );
  }

  Widget _buildAssignmentList(
      List<AssignmentModel> assignments, String emptyMsg) {
    if (assignments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined,
                size: 64, color: AppTheme.textHint),
            const SizedBox(height: 16),
            Text(emptyMsg,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 16)),
            if (!_moodleService.isConfigured) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _showMoodleSetup,
                icon: const Icon(Icons.link),
                label: const Text('Connect Moodle'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.assignmentsColor),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: assignments.length,
      itemBuilder: (context, i) => _buildAssignmentCard(assignments[i]),
    );
  }

  Widget _buildAssignmentCard(AssignmentModel a) {
    final isOverdue = a.isOverdue;
    final statusColor = _getStatusColor(a.status, isOverdue);
    final statusLabel = _getStatusLabel(a.status, isOverdue);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                if (a.fromMoodle)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_outlined,
                            size: 12, color: AppTheme.info),
                        SizedBox(width: 4),
                        Text('Moodle',
                            style: TextStyle(
                                color: AppTheme.info,
                                fontSize: 11)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              a.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              a.courseName,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary),
            ),
            if (a.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                a.description,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 14,
                  color: isOverdue ? AppTheme.error : AppTheme.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Due: ${DateFormat('MMM d, y').format(a.dueDate)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isOverdue ? AppTheme.error : AppTheme.textSecondary,
                    fontWeight:
                        isOverdue ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                if (a.grade != null) ...[
                  const Spacer(),
                  Text(
                    '${a.grade}/${a.maxGrade ?? '?'}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.success,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(AssignmentStatus status, bool isOverdue) {
    if (isOverdue) return AppTheme.error;
    switch (status) {
      case AssignmentStatus.submitted:
        return AppTheme.info;
      case AssignmentStatus.graded:
        return AppTheme.success;
      case AssignmentStatus.overdue:
        return AppTheme.error;
      default:
        return AppTheme.warning;
    }
  }

  String _getStatusLabel(AssignmentStatus status, bool isOverdue) {
    if (isOverdue) return 'Overdue';
    switch (status) {
      case AssignmentStatus.submitted:
        return 'Submitted';
      case AssignmentStatus.graded:
        return 'Graded';
      case AssignmentStatus.overdue:
        return 'Overdue';
      default:
        return 'Pending';
    }
  }

  void _showAddAssignmentDialog(BuildContext context, String familyId) {
    final titleCtrl = TextEditingController();
    final courseCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    DateTime dueDate = DateTime.now().add(const Duration(days: 7));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Assignment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: courseCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Course Name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Description (optional)'),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                      'Due: ${DateFormat('MMM d, y').format(dueDate)}'),
                  trailing:
                      const Icon(Icons.calendar_today, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: dueDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now()
                          .add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDialogState(() => dueDate = picked);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.isEmpty) return;
                final assignment = AssignmentModel(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: titleCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                  courseName: courseCtrl.text.trim().isEmpty
                      ? 'General'
                      : courseCtrl.text.trim(),
                  courseId: 'manual',
                  dueDate: dueDate,
                  status: AssignmentStatus.pending,
                  fromMoodle: false,
                  familyId: familyId,
                  createdAt: DateTime.now(),
                );
                await _firestoreService.saveAssignments([assignment]);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}
