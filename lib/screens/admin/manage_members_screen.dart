// lib/screens/admin/manage_members_screen.dart
// Admin can add members to any group/class/committee, assign mentor/second roles.
// Students auto-join classes; creating a new class adds the student immediately.
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/app_theme.dart';

class ManageMembersScreen extends StatefulWidget {
  final String? highlightUid;
  const ManageMembersScreen({super.key, this.highlightUid});

  @override
  State<ManageMembersScreen> createState() => _ManageMembersScreenState();
}

class _ManageMembersScreenState extends State<ManageMembersScreen> {
  final _db = FirebaseFirestore.instance;
  final _searchCtrl = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Manage Members'),
        backgroundColor: AppTheme.navy,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add_outlined),
            tooltip: 'Create New Group/Class',
            onPressed: () => _showCreateGroupDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search members…',
                prefixIcon: const Icon(Icons.search, size: 18),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                filled: true,
                fillColor: AppTheme.surface,
              ),
              onChanged: (v) => setState(() => _filter = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db.collection('users').snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                var docs = snap.data?.docs ?? [];
                if (_filter.isNotEmpty) {
                  docs = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    final name = (data['displayName'] as String? ?? '').toLowerCase();
                    final email = (data['email'] as String? ?? '').toLowerCase();
                    return name.contains(_filter) || email.contains(_filter);
                  }).toList();
                }
                if (docs.isEmpty) {
                  return const Center(
                    child: Text('No members found',
                        style: TextStyle(color: AppTheme.textHint)),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final uid = docs[i].id;
                    final name = data['displayName'] as String? ?? 'Unknown';
                    final email = data['email'] as String? ?? '';
                    final role = data['role'] as String? ?? 'parent';
                    final isHighlighted = uid == widget.highlightUid;
                    final isStudent = role == 'student' || role == 'kid';
                    final roleColor = role == 'admin'
                        ? const Color(0xFF7B1FA2)
                        : isStudent
                            ? AppTheme.gold
                            : AppTheme.navy;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isHighlighted
                            ? AppTheme.navy.withValues(alpha: 0.06)
                            : AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isHighlighted
                              ? AppTheme.navy.withValues(alpha: 0.3)
                              : AppTheme.cardBorder,
                        ),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              roleColor.withValues(alpha: 0.15),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(
                                color: roleColor,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        title: Text(name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text(email,
                            style: const TextStyle(fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: roleColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isStudent
                                    ? 'STUDENT'
                                    : role.toUpperCase(),
                                style: TextStyle(
                                    color: roleColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right, size: 18,
                                color: AppTheme.textHint),
                          ],
                        ),
                        onTap: () => _openMemberGroups(context, uid, name,
                            isStudent: isStudent),
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

  // ── Open member group assignment screen ─────────────────────────
  void _openMemberGroups(BuildContext context, String uid, String name,
      {required bool isStudent}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _MemberGroupsScreen(
          uid: uid,
          name: name,
          isStudent: isStudent,
        ),
      ),
    );
  }

  // ── Create new group / class dialog ────────────────────────────
  void _showCreateGroupDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    String groupType = 'class';
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setS) => AlertDialog(
          title: const Text('Create New Group'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Group / Class Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: groupType,
                decoration: const InputDecoration(
                    labelText: 'Type', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'class', child: Text('Class')),
                  DropdownMenuItem(
                      value: 'committee', child: Text('Committee')),
                  DropdownMenuItem(
                      value: 'mentor_group', child: Text('Mentor Group')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (v) => setS(() => groupType = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().isEmpty) return;
                      setS(() => saving = true);
                      await _db.collection('groups').add({
                        'name': nameCtrl.text.trim(),
                        'type': groupType,
                        'memberUids': [],
                        'mentorUids': [],
                        'secondUids': [],
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                '${nameCtrl.text.trim()} created!'),
                            backgroundColor: AppTheme.success,
                          ),
                        );
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Member Groups Assignment Screen ───────────────────────────────
class _MemberGroupsScreen extends StatefulWidget {
  final String uid;
  final String name;
  final bool isStudent;
  const _MemberGroupsScreen(
      {required this.uid, required this.name, required this.isStudent});

  @override
  State<_MemberGroupsScreen> createState() => _MemberGroupsScreenState();
}

class _MemberGroupsScreenState extends State<_MemberGroupsScreen> {
  final _db = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(widget.name),
        backgroundColor: AppTheme.navy,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Create & Assign New Group',
            onPressed: () => _createAndAssign(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('groups').snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.group_outlined,
                      size: 48, color: AppTheme.textHint),
                  const SizedBox(height: 12),
                  const Text('No groups exist yet',
                      style: TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _createAndAssign(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Group'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.navy),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final gData = docs[i].data() as Map<String, dynamic>;
              final gId = docs[i].id;
              final gName = gData['name'] as String? ?? 'Group';
              final gType = gData['type'] as String? ?? 'other';
              final members =
                  List<String>.from(gData['memberUids'] as List? ?? []);
              final mentors =
                  List<String>.from(gData['mentorUids'] as List? ?? []);
              final seconds =
                  List<String>.from(gData['secondUids'] as List? ?? []);

              final isMember = members.contains(widget.uid);
              final isMentor = mentors.contains(widget.uid);
              final isSecond = seconds.contains(widget.uid);

              return _GroupAssignmentTile(
                groupId: gId,
                groupName: gName,
                groupType: gType,
                isMember: isMember,
                isMentor: isMentor,
                isSecond: isSecond,
                isStudent: widget.isStudent,
                uid: widget.uid,
                userName: widget.name,
                db: _db,
              );
            },
          );
        },
      ),
    );
  }

  void _createAndAssign(BuildContext context) {
    final nameCtrl = TextEditingController();
    String groupType = widget.isStudent ? 'class' : 'committee';
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setS) => AlertDialog(
          title: Text('Create & Add ${widget.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Group / Class Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: groupType,
                decoration: const InputDecoration(
                    labelText: 'Type', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'class', child: Text('Class')),
                  DropdownMenuItem(
                      value: 'committee', child: Text('Committee')),
                  DropdownMenuItem(
                      value: 'mentor_group', child: Text('Mentor Group')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (v) => setS(() => groupType = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().isEmpty) return;
                      setS(() => saving = true);
                      await _db.collection('groups').add({
                        'name': nameCtrl.text.trim(),
                        'type': groupType,
                        'memberUids': [widget.uid],
                        'memberNames': [widget.name],
                        'mentorUids': [],
                        'secondUids': [],
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                '${widget.name} added to ${nameCtrl.text.trim()}!'),
                            backgroundColor: AppTheme.success,
                          ),
                        );
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Create & Add'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Group Assignment Tile ──────────────────────────────────────────
class _GroupAssignmentTile extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String groupType;
  final bool isMember;
  final bool isMentor;
  final bool isSecond;
  final bool isStudent;
  final String uid;
  final String userName;
  final FirebaseFirestore db;

  const _GroupAssignmentTile({
    required this.groupId,
    required this.groupName,
    required this.groupType,
    required this.isMember,
    required this.isMentor,
    required this.isSecond,
    required this.isStudent,
    required this.uid,
    required this.userName,
    required this.db,
  });

  @override
  State<_GroupAssignmentTile> createState() => _GroupAssignmentTileState();
}

class _GroupAssignmentTileState extends State<_GroupAssignmentTile> {
  bool _saving = false;

  Color get _typeColor {
    switch (widget.groupType) {
      case 'class':
        return AppTheme.assignmentsColor;
      case 'committee':
        return AppTheme.navy;
      case 'mentor_group':
        return AppTheme.prayerColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  Future<void> _toggleMember(bool add) async {
    setState(() => _saving = true);
    try {
      final ref = widget.db.collection('groups').doc(widget.groupId);
      if (add) {
        await ref.update({
          'memberUids': FieldValue.arrayUnion([widget.uid]),
          'memberNames': FieldValue.arrayUnion([widget.userName]),
        });
      } else {
        await ref.update({
          'memberUids': FieldValue.arrayRemove([widget.uid]),
          'memberNames': FieldValue.arrayRemove([widget.userName]),
          'mentorUids': FieldValue.arrayRemove([widget.uid]),
          'secondUids': FieldValue.arrayRemove([widget.uid]),
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleRole(String role, bool add) async {
    setState(() => _saving = true);
    try {
      final ref = widget.db.collection('groups').doc(widget.groupId);
      final field = role == 'mentor' ? 'mentorUids' : 'secondUids';
      // Also ensure member
      if (add) {
        await ref.update({
          field: FieldValue.arrayUnion([widget.uid]),
          'memberUids': FieldValue.arrayUnion([widget.uid]),
          'memberNames': FieldValue.arrayUnion([widget.userName]),
        });
      } else {
        await ref.update({
          field: FieldValue.arrayRemove([widget.uid]),
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isMember
              ? _typeColor.withValues(alpha: 0.4)
              : AppTheme.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: _typeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.groupType.toUpperCase().replaceAll('_', ' '),
                  style: TextStyle(
                      color: _typeColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.groupName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              if (_saving)
                const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
              else
                Checkbox(
                  value: widget.isMember,
                  activeColor: _typeColor,
                  onChanged: (v) => _toggleMember(v!),
                ),
            ],
          ),
          // Role chips (only for non-students / parents)
          if (!widget.isStudent && widget.isMember) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                _RoleChip(
                  label: 'Mentor',
                  active: widget.isMentor,
                  color: AppTheme.success,
                  onTap: () => _toggleRole('mentor', !widget.isMentor),
                ),
                const SizedBox(width: 8),
                _RoleChip(
                  label: 'Second',
                  active: widget.isSecond,
                  color: AppTheme.warning,
                  onTap: () => _toggleRole('second', !widget.isSecond),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _RoleChip({
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active
                  ? color
                  : AppTheme.cardBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? color : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
