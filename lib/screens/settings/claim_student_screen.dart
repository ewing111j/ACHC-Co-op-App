// lib/screens/settings/claim_student_screen.dart
// Allows a parent to claim (link) an imported student account to their family.
// Shows all unclaimed students sorted with same-last-name matches first.
// Also allows creating a brand-new student not on the imported list.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../utils/app_theme.dart';

class ClaimStudentScreen extends StatefulWidget {
  final UserModel parentUser;
  const ClaimStudentScreen({super.key, required this.parentUser});

  @override
  State<ClaimStudentScreen> createState() => _ClaimStudentScreenState();
}

class _ClaimStudentScreenState extends State<ClaimStudentScreen> {
  final _db = FirebaseFirestore.instance;
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() =>
        setState(() => _query = _searchCtrl.text.toLowerCase()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // Parent's last name for sorting
  String get _parentLastName {
    final parts = widget.parentUser.displayName.trim().split(' ');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  Future<void> _claimStudent(String studentUid, String studentName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Claim Student'),
        content: Text(
            'Link "$studentName" to your family?\n\n'
            'You will be able to monitor their classes and progress.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.classesColor,
                foregroundColor: Colors.white),
            child: const Text('Claim'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      final batch = _db.batch();
      // Add kid to parent's kidUids
      batch.update(_db.collection('users').doc(widget.parentUser.uid), {
        'kidUids': FieldValue.arrayUnion([studentUid]),
      });
      // Set parentUid on student + clear needsClaim
      batch.update(_db.collection('users').doc(studentUid), {
        'parentUid': widget.parentUser.uid,
        'needsClaim': false,
        'familyId': widget.parentUser.familyId ?? widget.parentUser.uid,
      });
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ $studentName linked to your family!'),
          backgroundColor: AppTheme.success,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showCreateNewStudentDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final gradeCtrl = TextEditingController();
    bool creating = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setS) => AlertDialog(
          title: const Text('Create New Student'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  'Create a student account not in the imported list.',
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Full Name*', isDense: true),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(
                    labelText: 'Email (optional)', isDense: true),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: gradeCtrl,
                decoration: const InputDecoration(
                    labelText: 'Grade Level (optional)', isDense: true),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: creating
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      setS(() => creating = true);
                      try {
                        final docRef = _db.collection('users').doc();
                        final batch = _db.batch();
                        batch.set(docRef, {
                          'uid': docRef.id,
                          'displayName': name,
                          'email': emailCtrl.text.trim().toLowerCase(),
                          'role': 'student',
                          'isMentor': false,
                          'mentorClassIds': [],
                          'kidUids': [],
                          'isActive': true,
                          'grade': gradeCtrl.text.trim(),
                          'parentUid': widget.parentUser.uid,
                          'familyId': widget.parentUser.familyId ??
                              widget.parentUser.uid,
                          'needsClaim': false,
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                        batch.update(
                            _db
                                .collection('users')
                                .doc(widget.parentUser.uid),
                            {
                              'kidUids':
                                  FieldValue.arrayUnion([docRef.id]),
                            });
                        await batch.commit();
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(
                            content:
                                Text('✅ $name created and linked!'),
                            backgroundColor: AppTheme.success,
                          ));
                          Navigator.pop(context);
                        }
                      } catch (e) {
                        if (ctx2.mounted) setS(() => creating = false);
                        if (ctx2.mounted) {
                          ScaffoldMessenger.of(ctx2).showSnackBar(SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: AppTheme.error));
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.classesColor,
                  foregroundColor: Colors.white),
              child: creating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Claim Student'),
        backgroundColor: AppTheme.navy,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined),
            tooltip: 'Create new student',
            onPressed: _showCreateNewStudentDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Info banner
          Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.classesColor.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppTheme.classesColor.withValues(alpha: 0.25)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: AppTheme.classesColor),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'These students were imported by an admin. '
                    'Tap a name to link them to your family. '
                    'Students sorted with matching last names first.',
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by name…',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () => _searchCtrl.clear(),
                      )
                    : null,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Student list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('users')
                  .where('role', isEqualTo: 'student')
                  .where('needsClaim', isEqualTo: true)
                  .snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                var docs = snap.data?.docs ?? [];

                // Apply search filter
                if (_query.isNotEmpty) {
                  docs = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    final name = (data['displayName'] as String? ?? '')
                        .toLowerCase();
                    return name.contains(_query);
                  }).toList();
                }

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_outline,
                            size: 48,
                            color: AppTheme.textHint),
                        const SizedBox(height: 12),
                        Text(
                          _query.isNotEmpty
                              ? 'No students match "$_query"'
                              : 'No unclaimed students found.\n'
                                  'All imported students have been claimed,\n'
                                  'or none have been imported yet.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _showCreateNewStudentDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Create New Student'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.classesColor,
                              foregroundColor: Colors.white),
                        ),
                      ],
                    ),
                  );
                }

                // Sort: same-last-name first, then alphabetical
                final sorted = [...docs];
                sorted.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aLast = (aData['lastName'] as String? ?? '')
                      .toLowerCase();
                  final bLast = (bData['lastName'] as String? ?? '')
                      .toLowerCase();
                  final aName = (aData['displayName'] as String? ?? '')
                      .toLowerCase();
                  final bName = (bData['displayName'] as String? ?? '')
                      .toLowerCase();

                  final aMatch = aLast == _parentLastName ? 0 : 1;
                  final bMatch = bLast == _parentLastName ? 0 : 1;
                  if (aMatch != bMatch) return aMatch - bMatch;
                  return aName.compareTo(bName);
                });

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 4),
                  itemCount: sorted.length,
                  itemBuilder: (_, i) {
                    final data =
                        sorted[i].data() as Map<String, dynamic>;
                    final uid = sorted[i].id;
                    final name =
                        data['displayName'] as String? ?? 'Unknown';
                    final email = data['email'] as String? ?? '';
                    final grade = data['grade'] as String? ?? '';
                    final lastName =
                        (data['lastName'] as String? ?? '')
                            .toLowerCase();
                    final isMatch = lastName == _parentLastName &&
                        _parentLastName.isNotEmpty;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isMatch
                              ? AppTheme.classesColor
                                  .withValues(alpha: 0.5)
                              : AppTheme.cardBorder,
                        ),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isMatch
                              ? AppTheme.classesColor.withValues(alpha: 0.15)
                              : AppTheme.navy.withValues(alpha: 0.10),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isMatch
                                  ? AppTheme.classesColor
                                  : AppTheme.navy,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(name,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                            ),
                            if (isMatch)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.classesColor
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'LAST NAME MATCH',
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.classesColor),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          [
                            if (email.isNotEmpty) email,
                            if (grade.isNotEmpty) 'Grade $grade',
                          ].join(' · '),
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary),
                        ),
                        trailing: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : ElevatedButton(
                                onPressed: () =>
                                    _claimStudent(uid, name),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      AppTheme.classesColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('Claim',
                                    style: TextStyle(fontSize: 12)),
                              ),
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
