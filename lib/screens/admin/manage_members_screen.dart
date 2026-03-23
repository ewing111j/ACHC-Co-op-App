// lib/screens/admin/manage_members_screen.dart
// Admin: manage users, enroll students in Classes, enroll parents in Group Chats
// Terminology:
//   • Classes (Firestore: 'classes' collection) → for students only
//   • Groups/Committees (Firestore: 'chatRooms' w/ roomType='committee') → for parents; also includes mentors+admins
//   • 'mentor_group' type is REMOVED — use class | committee | other
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/app_theme.dart';
import '../../models/user_model.dart';

class ManageMembersScreen extends StatefulWidget {
  final String? highlightUid;
  const ManageMembersScreen({super.key, this.highlightUid});

  @override
  State<ManageMembersScreen> createState() => _ManageMembersScreenState();
}

class _ManageMembersScreenState extends State<ManageMembersScreen>
    with SingleTickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;
  final _searchCtrl = TextEditingController();
  String _filter = '';
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _searchCtrl.addListener(() => setState(() => _filter = _searchCtrl.text.toLowerCase()));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
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
            tooltip: 'Create Group Chat',
            onPressed: () => _showCreateGroupDialog(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: AppTheme.gold,
          tabs: const [
            Tab(text: 'Students'),
            Tab(text: 'Parents'),
            Tab(text: 'All'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search members…',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _filter.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () => _searchCtrl.clear())
                    : null,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                filled: true,
                fillColor: AppTheme.surface,
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                // Students tab: can enroll in Classes
                _UserList(
                  db: _db,
                  filter: _filter,
                  roleFilter: ['student'],
                  highlightUid: widget.highlightUid,
                  onTap: (uid, name) => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => _StudentClassesScreen(
                              uid: uid, name: name, db: _db))),
                  emptyMessage: 'No students found',
                ),
                // Parents tab: can enroll in Group Chats (Committees)
                _UserList(
                  db: _db,
                  filter: _filter,
                  roleFilter: ['parent', 'mentor', 'admin'],
                  highlightUid: widget.highlightUid,
                  onTap: (uid, name) => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => _ParentGroupsScreen(
                              uid: uid, name: name, db: _db))),
                  emptyMessage: 'No parents/mentors found',
                ),
                // All tab
                _UserList(
                  db: _db,
                  filter: _filter,
                  roleFilter: null,
                  highlightUid: widget.highlightUid,
                  onTap: (uid, name) {
                    // Route by role
                    Navigator.push(context, MaterialPageRoute(builder: (_) {
                      return _UniversalMemberScreen(
                          uid: uid, name: name, db: _db);
                    }));
                  },
                  emptyMessage: 'No members found',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateGroupDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    String groupType = 'committee';
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setS) => AlertDialog(
          title: const Text('Create Group Chat'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Group Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: groupType,
                decoration: const InputDecoration(
                    labelText: 'Type', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'committee', child: Text('Committee')),
                  DropdownMenuItem(value: 'class', child: Text('Class Group')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (v) => setS(() => groupType = v!),
              ),
              const SizedBox(height: 8),
              const Text(
                'This creates a permanent group chat. '
                'To enroll students in a class for coursework, '
                'use the Students tab.',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
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
                      await _db.collection('chatRooms').add({
                        'name': nameCtrl.text.trim(),
                        'roomType': 'committee',
                        'groupSubType': groupType,
                        'isGroup': true,
                        'members': [],
                        'memberNames': [],
                        'lastMessage': '',
                        'lastMessageAt': FieldValue.serverTimestamp(),
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      // Also create in 'groups' collection for attendance/admin
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
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('${nameCtrl.text.trim()} created!'),
                          backgroundColor: AppTheme.success,
                        ));
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.navy),
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Create', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reusable user list ────────────────────────────────────────────────────────
class _UserList extends StatelessWidget {
  final FirebaseFirestore db;
  final String filter;
  final List<String>? roleFilter; // null = all
  final String? highlightUid;
  final void Function(String uid, String name) onTap;
  final String emptyMessage;

  const _UserList({
    required this.db,
    required this.filter,
    required this.roleFilter,
    required this.onTap,
    required this.emptyMessage,
    this.highlightUid,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db.collection('users').snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        var docs = snap.data?.docs ?? [];

        // Role filter
        if (roleFilter != null) {
          docs = docs.where((d) {
            final role = (d.data() as Map)['role'] as String? ?? 'parent';
            return roleFilter!.contains(role);
          }).toList();
        }

        // Search filter
        if (filter.isNotEmpty) {
          docs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final name = (data['displayName'] as String? ?? '').toLowerCase();
            final email = (data['email'] as String? ?? '').toLowerCase();
            return name.contains(filter) || email.contains(filter);
          }).toList();
        }

        // Sort by name
        docs.sort((a, b) {
          final n1 = (a.data() as Map)['displayName'] as String? ?? '';
          final n2 = (b.data() as Map)['displayName'] as String? ?? '';
          return n1.compareTo(n2);
        });

        if (docs.isEmpty) {
          return Center(
            child: Text(emptyMessage,
                style: const TextStyle(color: AppTheme.textSecondary)),
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
            final isHighlighted = uid == highlightUid;
            final isStudent = role == 'student';
            final isMentor = data['isMentor'] as bool? ?? false;
            final roleColor = role == 'admin'
                ? const Color(0xFF7B1FA2)
                : isStudent
                    ? AppTheme.gold
                    : isMentor
                        ? AppTheme.classesColor
                        : AppTheme.navy;
            final roleLabel = role == 'admin'
                ? 'ADMIN'
                : isStudent
                    ? 'STUDENT'
                    : isMentor
                        ? 'MENTOR'
                        : 'PARENT';

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
                  backgroundColor: roleColor.withValues(alpha: 0.15),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                        color: roleColor, fontWeight: FontWeight.w700),
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
                      child: Text(roleLabel,
                          style: TextStyle(
                              color: roleColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 4),
                    // Role change popup
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert,
                          size: 18, color: AppTheme.textHint),
                      tooltip: 'Change role',
                      onSelected: (newRole) async {
                        await db
                            .collection('users')
                            .doc(uid)
                            .update({'role': newRole});
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(
                                '$name role → ${newRole.toUpperCase()}'),
                            backgroundColor: AppTheme.success,
                            behavior: SnackBarBehavior.floating,
                          ));
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                            value: 'student',
                            child: Row(children: [
                              Icon(Icons.school_outlined, size: 16),
                              SizedBox(width: 8),
                              Text('Set as Student'),
                            ])),
                        const PopupMenuItem(
                            value: 'parent',
                            child: Row(children: [
                              Icon(Icons.family_restroom, size: 16),
                              SizedBox(width: 8),
                              Text('Set as Parent'),
                            ])),
                        const PopupMenuItem(
                            value: 'mentor',
                            child: Row(children: [
                              Icon(Icons.workspace_premium_outlined, size: 16),
                              SizedBox(width: 8),
                              Text('Set as Mentor'),
                            ])),
                        const PopupMenuItem(
                            value: 'admin',
                            child: Row(children: [
                              Icon(Icons.admin_panel_settings_outlined,
                                  size: 16),
                              SizedBox(width: 8),
                              Text('Set as Admin'),
                            ])),
                      ],
                    ),
                  ],
                ),
                onTap: () => onTap(uid, name),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Student → Classes enrollment screen ──────────────────────────────────────
class _StudentClassesScreen extends StatefulWidget {
  final String uid;
  final String name;
  final FirebaseFirestore db;
  const _StudentClassesScreen(
      {required this.uid, required this.name, required this.db});

  @override
  State<_StudentClassesScreen> createState() => _StudentClassesScreenState();
}

class _StudentClassesScreenState extends State<_StudentClassesScreen> {
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
            icon: const Icon(Icons.info_outline, size: 18),
            tooltip: 'Classes are for coursework. Toggle to enroll/unenroll.',
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'Toggle classes to enroll or unenroll this student.')),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: widget.db
            .collection('classes')
            .where('isArchived', isEqualTo: false)
            .snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(
                child: Text('No classes found. Create classes first.',
                    style:
                        TextStyle(color: AppTheme.textSecondary)));
          }
          // Sort by name
          final sorted = [...docs];
          sorted.sort((a, b) {
            final n1 = (a.data() as Map)['name'] as String? ?? '';
            final n2 = (b.data() as Map)['name'] as String? ?? '';
            return n1.compareTo(n2);
          });
          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: sorted.length,
            itemBuilder: (_, i) {
              final data = sorted[i].data() as Map<String, dynamic>;
              final classId = sorted[i].id;
              final className = data['name'] as String? ?? '';
              final enrolled =
                  List<String>.from(data['enrolledUids'] as List? ?? []);
              final isEnrolled = enrolled.contains(widget.uid);
              final colorVal =
                  data['colorValue'] as int? ?? 0xFF283593;

              return _ClassEnrollTile(
                classId: classId,
                className: className,
                colorValue: colorVal,
                isEnrolled: isEnrolled,
                db: widget.db,
                studentUid: widget.uid,
                studentName: widget.name,
              );
            },
          );
        },
      ),
    );
  }
}

class _ClassEnrollTile extends StatefulWidget {
  final String classId;
  final String className;
  final int colorValue;
  final bool isEnrolled;
  final FirebaseFirestore db;
  final String studentUid;
  final String studentName;

  const _ClassEnrollTile({
    required this.classId,
    required this.className,
    required this.colorValue,
    required this.isEnrolled,
    required this.db,
    required this.studentUid,
    required this.studentName,
  });

  @override
  State<_ClassEnrollTile> createState() => _ClassEnrollTileState();
}

class _ClassEnrollTileState extends State<_ClassEnrollTile> {
  bool _saving = false;

  Future<void> _toggle(bool enroll) async {
    setState(() => _saving = true);
    try {
      await widget.db.collection('classes').doc(widget.classId).update({
        'enrolledUids': enroll
            ? FieldValue.arrayUnion([widget.studentUid])
            : FieldValue.arrayRemove([widget.studentUid]),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: AppTheme.error));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(widget.colorValue);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: widget.isEnrolled
              ? color.withValues(alpha: 0.5)
              : AppTheme.cardBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(6)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(widget.className,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500)),
          ),
          if (_saving)
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
          else
            Switch.adaptive(
              value: widget.isEnrolled,
              activeColor: color,
              onChanged: _toggle,
            ),
        ],
      ),
    );
  }
}

// ── Parent → Group Chats (committees) enrollment screen ──────────────────────
class _ParentGroupsScreen extends StatefulWidget {
  final String uid;
  final String name;
  final FirebaseFirestore db;
  const _ParentGroupsScreen(
      {required this.uid, required this.name, required this.db});

  @override
  State<_ParentGroupsScreen> createState() => _ParentGroupsScreenState();
}

class _ParentGroupsScreenState extends State<_ParentGroupsScreen> {
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
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Group Chats (Committees)',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.navy),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Toggle to add/remove from group chats. '
              'Classes are separate from group chats.',
              style:
                  TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: widget.db
                  .collection('chatRooms')
                  .where('roomType', isEqualTo: 'committee')
                  .snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return const Center(
                      child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Center(
                    child: Text('No group chats found.\nCreate one from the + button.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppTheme.textSecondary)),
                  );
                }
                // Sort by name
                final sorted = [...docs];
                sorted.sort((a, b) {
                  final n1 = (a.data() as Map)['name'] as String? ?? '';
                  final n2 = (b.data() as Map)['name'] as String? ?? '';
                  return n1.compareTo(n2);
                });
                return ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: sorted.length,
                  itemBuilder: (_, i) {
                    final data =
                        sorted[i].data() as Map<String, dynamic>;
                    final roomId = sorted[i].id;
                    final roomName = data['name'] as String? ?? '';
                    final subType =
                        data['groupSubType'] as String? ?? 'committee';
                    final members = List<String>.from(
                        data['members'] as List? ?? []);
                    final isMember = members.contains(widget.uid);

                    return _GroupChatEnrollTile(
                      roomId: roomId,
                      roomName: roomName,
                      subType: subType,
                      isMember: isMember,
                      db: widget.db,
                      uid: widget.uid,
                      userName: widget.name,
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

class _GroupChatEnrollTile extends StatefulWidget {
  final String roomId;
  final String roomName;
  final String subType;
  final bool isMember;
  final FirebaseFirestore db;
  final String uid;
  final String userName;

  const _GroupChatEnrollTile({
    required this.roomId,
    required this.roomName,
    required this.subType,
    required this.isMember,
    required this.db,
    required this.uid,
    required this.userName,
  });

  @override
  State<_GroupChatEnrollTile> createState() => _GroupChatEnrollTileState();
}

class _GroupChatEnrollTileState extends State<_GroupChatEnrollTile> {
  bool _saving = false;

  Future<void> _toggle(bool add) async {
    setState(() => _saving = true);
    try {
      await widget.db.collection('chatRooms').doc(widget.roomId).update({
        'members': add
            ? FieldValue.arrayUnion([widget.uid])
            : FieldValue.arrayRemove([widget.uid]),
        'memberNames': add
            ? FieldValue.arrayUnion([widget.userName])
            : FieldValue.arrayRemove([widget.userName]),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: AppTheme.error));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Color get _typeColor {
    switch (widget.subType) {
      case 'class':
        return AppTheme.classesColor;
      case 'other':
        return AppTheme.calendarColor;
      default:
        return AppTheme.navy;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: widget.isMember
              ? _typeColor.withValues(alpha: 0.5)
              : AppTheme.cardBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _typeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              widget.subType.toUpperCase(),
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: _typeColor),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(widget.roomName,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500)),
          ),
          if (_saving)
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
          else
            Switch.adaptive(
              value: widget.isMember,
              activeColor: _typeColor,
              onChanged: _toggle,
            ),
        ],
      ),
    );
  }
}

// ── Universal screen (All tab) — routes to student or parent screen ───────────
class _UniversalMemberScreen extends StatelessWidget {
  final String uid;
  final String name;
  final FirebaseFirestore db;
  const _UniversalMemberScreen(
      {required this.uid, required this.name, required this.db});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: db.collection('users').doc(uid).get(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final data = snap.data!.data() as Map<String, dynamic>? ?? {};
        final role = data['role'] as String? ?? 'parent';
        final isStudent = role == 'student';

        if (isStudent) {
          return _StudentClassesScreen(uid: uid, name: name, db: db);
        } else {
          return _ParentGroupsScreen(uid: uid, name: name, db: db);
        }
      },
    );
  }
}
