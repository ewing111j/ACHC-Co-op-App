// lib/screens/messages/messages_screen.dart
// Two messaging sections:
// 1) Committee & Class – admin-created group chats; auto-appear for assigned members
// 2) Personal – direct messages and user-created group chats
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../utils/app_theme.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser!;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Messages'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.school_outlined, size: 18), text: 'Committee & Class'),
            Tab(icon: Icon(Icons.chat_bubble_outline, size: 18), text: 'Personal'),
          ],
        ),
        actions: [
          // Admin: manage committee/class groups in tab 0
          if (_tabController.index == 0 && user.isAdmin)
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Create Group',
              onPressed: () => _showCreateGroupSheet(context, user, isCommittee: true),
            ),
          // Everyone (non-kid): create personal chats in tab 1
          if (_tabController.index == 1 && !user.isStudent)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'New Chat',
              onPressed: () => _showNewPersonalChat(context, user),
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 0 – Committee & Class
          _CommitteeClassTab(user: user, db: _db),
          // Tab 1 – Personal
          _PersonalTab(user: user, db: _db),
        ],
      ),
    );
  }

  void _showCreateGroupSheet(BuildContext context, UserModel user,
      {required bool isCommittee}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateGroupSheet(user: user, db: _db, isCommitteeType: true),
    );
  }

  void _showNewPersonalChat(BuildContext context, UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewPersonalChatSheet(user: user, db: _db),
    );
  }
}

// ── COMMITTEE & CLASS TAB ────────────────────────────────────────
class _CommitteeClassTab extends StatelessWidget {
  final UserModel user;
  final FirebaseFirestore db;
  const _CommitteeClassTab({required this.user, required this.db});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db
          .collection('chatRooms')
          .where('members', arrayContains: user.uid)
          .where('roomType', isEqualTo: 'committee')
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];

        // Sort in-memory by last message time
        final sorted = [...docs];
        sorted.sort((a, b) {
          final aT = (a.data() as Map)['lastMessageAt'];
          final bT = (b.data() as Map)['lastMessageAt'];
          if (aT == null) return 1;
          if (bT == null) return -1;
          return (bT as Timestamp)
              .compareTo(aT as Timestamp);
        });

        if (sorted.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.school_outlined, size: 64, color: AppTheme.textHint),
                const SizedBox(height: 16),
                const Text('No committee or class groups yet',
                    style: TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                if (user.isAdmin)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Tap + above to create a committee or class group chat. '
                      'Members will see it automatically.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textHint, fontSize: 13),
                    ),
                  )
                else
                  const Text('Your admin will add you to group chats',
                      style: TextStyle(color: AppTheme.textHint, fontSize: 13)),
              ],
            ),
          );
        }

        return Column(
          children: [
            if (user.isAdmin)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: AppTheme.navy.withValues(alpha: 0.06),
                child: Row(
                  children: [
                    const Icon(Icons.admin_panel_settings_outlined,
                        size: 16, color: AppTheme.navy),
                    const SizedBox(width: 8),
                    const Text('You manage these group chats',
                        style: TextStyle(fontSize: 12, color: AppTheme.navy,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) =>
                            _CreateGroupSheet(user: user, db: db, isCommitteeType: true),
                      ),
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('New Group', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                          foregroundColor: AppTheme.navy,
                          padding: const EdgeInsets.symmetric(horizontal: 8)),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: sorted.length,
                itemBuilder: (ctx, i) {
                  final d = sorted[i].data() as Map<String, dynamic>;
                  final roomId = sorted[i].id;
                  return _RoomTile(
                    roomId: roomId,
                    data: d,
                    user: user,
                    db: db,
                    isCommitteeRoom: true,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── PERSONAL TAB ─────────────────────────────────────────────────
class _PersonalTab extends StatelessWidget {
  final UserModel user;
  final FirebaseFirestore db;
  const _PersonalTab({required this.user, required this.db});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db
          .collection('chatRooms')
          .where('members', arrayContains: user.uid)
          .where('roomType', isEqualTo: 'personal')
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];

        final sorted = [...docs];
        sorted.sort((a, b) {
          final aT = (a.data() as Map)['lastMessageAt'];
          final bT = (b.data() as Map)['lastMessageAt'];
          if (aT == null) return 1;
          if (bT == null) return -1;
          return (bT as Timestamp).compareTo(aT as Timestamp);
        });

        if (sorted.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 64, color: AppTheme.textHint),
                const SizedBox(height: 16),
                const Text('No personal messages yet',
                    style: TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                if (!user.isStudent)
                  const Text('Tap + to start a direct message or group chat',
                      style: TextStyle(color: AppTheme.textHint, fontSize: 13)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: sorted.length,
          itemBuilder: (ctx, i) {
            final d = sorted[i].data() as Map<String, dynamic>;
            final roomId = sorted[i].id;
            return _RoomTile(
              roomId: roomId,
              data: d,
              user: user,
              db: db,
              isCommitteeRoom: false,
            );
          },
        );
      },
    );
  }
}

// ── Room Tile ─────────────────────────────────────────────────────
class _RoomTile extends StatelessWidget {
  final String roomId;
  final Map<String, dynamic> data;
  final UserModel user;
  final FirebaseFirestore db;
  final bool isCommitteeRoom;
  const _RoomTile({
    required this.roomId,
    required this.data,
    required this.user,
    required this.db,
    required this.isCommitteeRoom,
  });

  @override
  Widget build(BuildContext context) {
    final name = data['name'] as String? ?? 'Chat';
    final lastMsg = data['lastMessage'] as String? ?? '';
    final unread = data['unread_${user.uid}'] as int? ?? 0;
    final isGroup = data['isGroup'] as bool? ?? false;
    final lastAt = data['lastMessageAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(
            (data['lastMessageAt'] as Timestamp).millisecondsSinceEpoch)
        : null;
    final color = isCommitteeRoom ? AppTheme.navy : AppTheme.messagesColor;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(
              isCommitteeRoom
                  ? Icons.school_outlined
                  : (isGroup ? Icons.group : Icons.person),
              color: color,
              size: 22,
            ),
          ),
          if (unread > 0)
            Positioned(
              right: 0, top: 0,
              child: Container(
                width: 16, height: 16,
                decoration: BoxDecoration(
                    color: AppTheme.error, shape: BoxShape.circle),
                child: Center(
                  child: Text('$unread',
                      style: const TextStyle(color: Colors.white, fontSize: 9,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ),
        ],
      ),
      title: Text(name,
          style: TextStyle(
              fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w600,
              fontSize: 14)),
      subtitle: Text(lastMsg,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: unread > 0 ? AppTheme.textPrimary : AppTheme.textHint,
              fontSize: 12,
              fontWeight: unread > 0 ? FontWeight.w500 : FontWeight.normal)),
      trailing: lastAt != null
          ? Text(_formatTime(lastAt),
              style: const TextStyle(fontSize: 11, color: AppTheme.textHint))
          : null,
      onTap: () {
        db.collection('chatRooms').doc(roomId).update({'unread_${user.uid}': 0});
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              roomId: roomId,
              roomName: name,
              user: user,
              db: db,
              isCommitteeRoom: isCommitteeRoom,
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (now.difference(dt).inHours < 24) {
      return DateFormat('h:mm a').format(dt);
    }
    return DateFormat('MMM d').format(dt);
  }
}

// ── CREATE GROUP SHEET (Admin) ─────────────────────────────────────
class _CreateGroupSheet extends StatefulWidget {
  final UserModel user;
  final FirebaseFirestore db;
  final bool isCommitteeType;
  const _CreateGroupSheet(
      {required this.user, required this.db, required this.isCommitteeType});

  @override
  State<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<_CreateGroupSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  List<Map<String, dynamic>> _allUsers = [];
  final Set<String> _selectedUids = {};
  bool _loading = true;
  bool _saving = false;
  String _groupType = 'committee'; // committee | class

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    final snap = await widget.db.collection('users').get();
    final users = snap.docs
        .map((d) => {
              'uid': d.id,
              'name': d.data()['displayName'] as String? ?? 'User',
              'role': d.data()['role'] as String? ?? 'parent',
              'email': d.data()['email'] as String? ?? '',
            })
        .where((u) => u['uid'] != widget.user.uid)
        .toList();
    users.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    if (mounted) setState(() { _allUsers = users; _loading = false; });
  }

  Future<void> _create() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      // Admin is always a member
      final allMembers = [widget.user.uid, ..._selectedUids];
      final allMemberNames = <String>[widget.user.displayName];
      for (final uid in _selectedUids) {
        final u = _allUsers.firstWhere((m) => m['uid'] == uid,
            orElse: () => {'name': uid});
        allMemberNames.add(u['name'] as String);
      }

      await widget.db.collection('chatRooms').add({
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'roomType': 'committee',
        'groupSubType': _groupType,
        'isGroup': true,
        'members': allMembers,
        'memberNames': allMemberNames,
        'createdBy': widget.user.uid,
        'createdByName': widget.user.displayName,
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.6,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Create Group Chat',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Georgia')),
                  ),
                  TextButton(
                    onPressed: _saving ? null : _create,
                    child: _saving
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Create'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.all(20),
                children: [
                  // Type selector
                  Row(
                    children: [
                      Expanded(
                        child: _TypeChip(
                          label: 'Committee',
                          icon: Icons.groups_outlined,
                          selected: _groupType == 'committee',
                          onTap: () => setState(() => _groupType = 'committee'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _TypeChip(
                          label: 'Class',
                          icon: Icons.school_outlined,
                          selected: _groupType == 'class',
                          onTap: () => setState(() => _groupType = 'class'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Group Name',
                      hintText: 'e.g. Science Committee, Math 101',
                      prefixIcon: Icon(Icons.group_work_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      prefixIcon: Icon(Icons.info_outline),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Text('Add Members',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      const Spacer(),
                      Text('${_selectedUids.length} selected',
                          style: const TextStyle(
                              color: AppTheme.textHint, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_loading)
                    const Center(child: CircularProgressIndicator())
                  else
                    ..._allUsers.map((u) {
                      final uid = u['uid'] as String;
                      final selected = _selectedUids.contains(uid);
                      final role = u['role'] as String;
                      return CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: selected,
                        onChanged: (v) {
                          setState(() {
                            if (v == true) _selectedUids.add(uid);
                            else _selectedUids.remove(uid);
                          });
                        },
                        secondary: CircleAvatar(
                          radius: 16,
                          backgroundColor: AppTheme.navy.withValues(alpha: 0.1),
                          child: Text(
                            (u['name'] as String).isNotEmpty
                                ? (u['name'] as String)[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: AppTheme.navy,
                                fontSize: 12,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        title: Text(u['name'] as String,
                            style: const TextStyle(fontSize: 13)),
                        subtitle: Text(role,
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.textHint)),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _TypeChip(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.navy : AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? AppTheme.navy : AppTheme.cardBorder),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: selected ? Colors.white : AppTheme.textSecondary,
                size: 20),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: selected ? Colors.white : AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ── NEW PERSONAL CHAT SHEET ────────────────────────────────────────
class _NewPersonalChatSheet extends StatefulWidget {
  final UserModel user;
  final FirebaseFirestore db;
  const _NewPersonalChatSheet({required this.user, required this.db});

  @override
  State<_NewPersonalChatSheet> createState() => _NewPersonalChatSheetState();
}

class _NewPersonalChatSheetState extends State<_NewPersonalChatSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _allUsers = [];
  final Set<String> _selectedUids = {};
  final _groupNameCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadUsers();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _groupNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    final snap = await widget.db.collection('users').get();
    final users = snap.docs
        .map((d) => {
              'uid': d.id,
              'name': d.data()['displayName'] as String? ?? 'User',
              'role': d.data()['role'] as String? ?? 'parent',
            })
        .where((u) => u['uid'] != widget.user.uid)
        .toList();
    users.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    if (mounted) setState(() { _allUsers = users; _loading = false; });
  }

  Future<void> _startDirect(String otherUid, String otherName) async {
    // Check if DM already exists
    final snap = await widget.db
        .collection('chatRooms')
        .where('members', arrayContains: widget.user.uid)
        .where('roomType', isEqualTo: 'personal')
        .where('isGroup', isEqualTo: false)
        .get();
    String? existingId;
    for (final doc in snap.docs) {
      final members = List<String>.from(doc.data()['members'] as List? ?? []);
      if (members.contains(otherUid)) { existingId = doc.id; break; }
    }
    if (existingId == null) {
      final ref = widget.db.collection('chatRooms').doc();
      await ref.set({
        'name': otherName,
        'roomType': 'personal',
        'isGroup': false,
        'members': [widget.user.uid, otherUid],
        'memberNames': [widget.user.displayName, otherName],
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      existingId = ref.id;
    }
    if (mounted) {
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            roomId: existingId!,
            roomName: otherName,
            user: widget.user,
            db: widget.db,
            isCommitteeRoom: false,
          ),
        ),
      );
    }
  }

  Future<void> _createGroup() async {
    if (_selectedUids.isEmpty || _groupNameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final allMembers = [widget.user.uid, ..._selectedUids];
      final allNames = <String>[widget.user.displayName];
      for (final uid in _selectedUids) {
        final u = _allUsers.firstWhere((m) => m['uid'] == uid,
            orElse: () => {'name': uid});
        allNames.add(u['name'] as String);
      }
      await widget.db.collection('chatRooms').add({
        'name': _groupNameCtrl.text.trim(),
        'roomType': 'personal',
        'isGroup': true,
        'members': allMembers,
        'memberNames': allNames,
        'createdBy': widget.user.uid,
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Text('New Message',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Georgia')),
            ),
            TabBar(
              controller: _tabs,
              tabs: const [
                Tab(text: 'Direct Message'),
                Tab(text: 'Group Chat'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  // Direct messages
                  _loading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          controller: ctrl,
                          itemCount: _allUsers.length,
                          itemBuilder: (_, i) {
                            final u = _allUsers[i];
                            return ListTile(
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor:
                                    AppTheme.messagesColor.withValues(alpha: 0.1),
                                child: Text(
                                  (u['name'] as String)[0].toUpperCase(),
                                  style: const TextStyle(
                                      color: AppTheme.messagesColor,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                              title: Text(u['name'] as String,
                                  style: const TextStyle(fontSize: 14)),
                              subtitle: Text(u['role'] as String,
                                  style: const TextStyle(
                                      fontSize: 11, color: AppTheme.textHint)),
                              onTap: () =>
                                  _startDirect(u['uid'] as String, u['name'] as String),
                            );
                          },
                        ),
                  // Group chat
                  ListView(
                    controller: ctrl,
                    padding: const EdgeInsets.all(16),
                    children: [
                      TextField(
                        controller: _groupNameCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Group Name',
                            prefixIcon: Icon(Icons.group_outlined)),
                      ),
                      const SizedBox(height: 16),
                      Text(
                          'Select Members (${_selectedUids.length} selected)',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 8),
                      if (_loading)
                        const Center(child: CircularProgressIndicator())
                      else
                        ..._allUsers.map((u) {
                          final uid = u['uid'] as String;
                          return CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: _selectedUids.contains(uid),
                            onChanged: (v) {
                              setState(() {
                                if (v == true) _selectedUids.add(uid);
                                else _selectedUids.remove(uid);
                              });
                            },
                            title: Text(u['name'] as String,
                                style: const TextStyle(fontSize: 13)),
                            subtitle: Text(u['role'] as String,
                                style: const TextStyle(
                                    fontSize: 11, color: AppTheme.textHint)),
                          );
                        }),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _createGroup,
                          child: _saving
                              ? const SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text('Create Group Chat'),
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
}

// ── CHAT SCREEN ───────────────────────────────────────────────────
class ChatScreen extends StatefulWidget {
  final String roomId;
  final String roomName;
  final UserModel user;
  final FirebaseFirestore db;
  final bool isCommitteeRoom;
  const ChatScreen({
    super.key,
    required this.roomId,
    required this.roomName,
    required this.user,
    required this.db,
    this.isCommitteeRoom = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;
  bool _showPoll = false;
  final List<TextEditingController> _pollOpts = [
    TextEditingController(),
    TextEditingController(),
  ];
  final _pollQCtrl = TextEditingController();
  Map<String, dynamic>? _roomData;

  @override
  void initState() {
    super.initState();
    _loadRoomData();
  }

  Future<void> _loadRoomData() async {
    final doc = await widget.db.collection('chatRooms').doc(widget.roomId).get();
    if (mounted && doc.exists) {
      setState(() => _roomData = doc.data());
    }
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _pollQCtrl.dispose();
    for (final c in _pollOpts) c.dispose();
    super.dispose();
  }

  bool get _canSend => !widget.user.isStudent;

  @override
  Widget build(BuildContext context) {
    final memberCount =
        (_roomData?['members'] as List?)?.length ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.roomName,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            if (memberCount > 0)
              Text('$memberCount members',
                  style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_canSend)
            IconButton(
              icon: const Icon(Icons.poll_outlined),
              tooltip: 'Create Poll',
              onPressed: () => setState(() => _showPoll = !_showPoll),
            ),
          // Admin can manage committee room members
          if (widget.isCommitteeRoom && widget.user.isAdmin)
            IconButton(
              icon: const Icon(Icons.manage_accounts_outlined),
              tooltip: 'Manage Members',
              onPressed: () => _showManageMembers(context),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: widget.db
                  .collection('chatRooms')
                  .doc(widget.roomId)
                  .collection('messages')
                  .orderBy('createdAt', descending: false)
                  .limitToLast(100)
                  .snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? [];
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollCtrl.hasClients) {
                    _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
                  }
                });
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final d = docs[i].data() as Map<String, dynamic>;
                    final isMe = d['senderId'] == widget.user.uid;
                    final isPoll = d['type'] == 'poll';
                    return isPoll
                        ? _PollMessage(
                            data: d,
                            msgId: docs[i].id,
                            user: widget.user,
                            db: widget.db,
                            roomId: widget.roomId,
                          )
                        : _MessageBubble(data: d, isMe: isMe);
                  },
                );
              },
            ),
          ),
          if (_showPoll && _canSend)
            _PollCreator(
              question: _pollQCtrl,
              options: _pollOpts,
              onAddOption: () =>
                  setState(() => _pollOpts.add(TextEditingController())),
              onSend: _sendPoll,
              onClose: () => setState(() => _showPoll = false),
            ),
          if (_canSend)
            _InputBar(
              ctrl: _msgCtrl,
              sending: _sending,
              onSend: _sendMessage,
              onPoll: () => setState(() => _showPoll = !_showPoll),
            ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    _msgCtrl.clear();
    try {
      await widget.db
          .collection('chatRooms')
          .doc(widget.roomId)
          .collection('messages')
          .add({
        'type': 'text',
        'content': text,
        'senderId': widget.user.uid,
        'senderName': widget.user.displayName,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await widget.db.collection('chatRooms').doc(widget.roomId).update({
        'lastMessage': text,
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendPoll() async {
    final question = _pollQCtrl.text.trim();
    final opts =
        _pollOpts.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
    if (question.isEmpty || opts.length < 2) return;
    await widget.db
        .collection('chatRooms')
        .doc(widget.roomId)
        .collection('messages')
        .add({
      'type': 'poll',
      'question': question,
      'options': opts,
      'votes': {},
      'senderId': widget.user.uid,
      'senderName': widget.user.displayName,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await widget.db.collection('chatRooms').doc(widget.roomId).update({
      'lastMessage': '📊 Poll: $question',
      'lastMessageAt': FieldValue.serverTimestamp(),
    });
    _pollQCtrl.clear();
    for (final c in _pollOpts) c.clear();
    if (mounted) setState(() => _showPoll = false);
  }

  void _showManageMembers(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ManageMembersSheet(
        roomId: widget.roomId,
        db: widget.db,
        currentUser: widget.user,
        roomData: _roomData ?? {},
        onRefresh: _loadRoomData,
      ),
    );
  }
}

// ── MANAGE MEMBERS SHEET (Admin) ──────────────────────────────────
class _ManageMembersSheet extends StatefulWidget {
  final String roomId;
  final FirebaseFirestore db;
  final UserModel currentUser;
  final Map<String, dynamic> roomData;
  final VoidCallback onRefresh;
  const _ManageMembersSheet({
    required this.roomId,
    required this.db,
    required this.currentUser,
    required this.roomData,
    required this.onRefresh,
  });

  @override
  State<_ManageMembersSheet> createState() => _ManageMembersSheetState();
}

class _ManageMembersSheetState extends State<_ManageMembersSheet> {
  List<Map<String, dynamic>> _allUsers = [];
  late Set<String> _memberUids;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _memberUids = Set<String>.from(
        (widget.roomData['members'] as List?)?.cast<String>() ?? []);
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final snap = await widget.db.collection('users').get();
    final users = snap.docs
        .map((d) => {
              'uid': d.id,
              'name': d.data()['displayName'] as String? ?? 'User',
              'role': d.data()['role'] as String? ?? 'parent',
            })
        .toList();
    users.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    if (mounted) setState(() { _allUsers = users; _loading = false; });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final names = <String>[];
      for (final uid in _memberUids) {
        final u = _allUsers.firstWhere((m) => m['uid'] == uid,
            orElse: () => {'name': uid});
        names.add(u['name'] as String);
      }
      await widget.db.collection('chatRooms').doc(widget.roomId).update({
        'members': _memberUids.toList(),
        'memberNames': names,
      });
      widget.onRefresh();
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Manage Members',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Georgia')),
                  ),
                  TextButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Save'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: ctrl,
                      padding: const EdgeInsets.all(8),
                      itemCount: _allUsers.length,
                      itemBuilder: (_, i) {
                        final u = _allUsers[i];
                        final uid = u['uid'] as String;
                        final isAdmin = uid == widget.currentUser.uid;
                        return CheckboxListTile(
                          dense: true,
                          value: _memberUids.contains(uid),
                          onChanged: isAdmin
                              ? null
                              : (v) {
                                  setState(() {
                                    if (v == true) _memberUids.add(uid);
                                    else _memberUids.remove(uid);
                                  });
                                },
                          title: Text(u['name'] as String,
                              style: const TextStyle(fontSize: 13)),
                          subtitle: Text(
                              isAdmin ? 'Admin (always member)' : u['role'] as String,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: isAdmin
                                      ? AppTheme.navy
                                      : AppTheme.textHint)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Message Bubble ────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isMe;
  const _MessageBubble({required this.data, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final createdAt = data['createdAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(
            (data['createdAt'] as Timestamp).millisecondsSinceEpoch)
        : DateTime.now();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 2),
              child: Text(data['senderName'] as String? ?? '',
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textHint,
                      fontWeight: FontWeight.w600)),
            ),
          Container(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMe ? AppTheme.navy : AppTheme.surface,
              borderRadius: BorderRadius.circular(16).copyWith(
                bottomRight: isMe ? const Radius.circular(4) : null,
                bottomLeft: !isMe ? const Radius.circular(4) : null,
              ),
              border: isMe ? null : Border.all(color: AppTheme.cardBorder),
            ),
            child: Text(
              data['content'] as String? ?? '',
              style: TextStyle(
                color: isMe ? Colors.white : AppTheme.textPrimary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 8, right: 8),
            child: Text(DateFormat('h:mm a').format(createdAt),
                style: const TextStyle(fontSize: 10, color: AppTheme.textHint)),
          ),
        ],
      ),
    );
  }
}

// ── Poll Message ──────────────────────────────────────────────────
class _PollMessage extends StatelessWidget {
  final Map<String, dynamic> data;
  final String msgId;
  final UserModel user;
  final FirebaseFirestore db;
  final String roomId;
  const _PollMessage({
    required this.data,
    required this.msgId,
    required this.user,
    required this.db,
    required this.roomId,
  });

  @override
  Widget build(BuildContext context) {
    final question = data['question'] as String? ?? '';
    final options = List<String>.from(data['options'] as List? ?? []);
    final votes = Map<String, dynamic>.from(data['votes'] as Map? ?? {});
    final myVote = votes[user.uid] as int?;
    final totalVotes = votes.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.poll_outlined, size: 16, color: AppTheme.navy),
              const SizedBox(width: 6),
              const Text('Poll',
                  style: TextStyle(
                      color: AppTheme.navy,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('$totalVotes votes',
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textHint)),
            ],
          ),
          const SizedBox(height: 8),
          Text(question,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 10),
          ...options.asMap().entries.map((entry) {
            final idx = entry.key;
            final opt = entry.value;
            final voteCount =
                votes.values.where((v) => v == idx).length;
            final pct = totalVotes > 0 ? voteCount / totalVotes : 0.0;
            final isMyVote = myVote == idx;
            return GestureDetector(
              onTap: () => _vote(idx, votes),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                child: Stack(
                  children: [
                    Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isMyVote
                              ? AppTheme.navy
                              : AppTheme.cardBorder,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: pct,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.navy.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          children: [
                            if (isMyVote)
                              const Icon(Icons.check_circle,
                                  size: 14, color: AppTheme.navy),
                            if (isMyVote) const SizedBox(width: 4),
                            Expanded(
                              child: Text(opt,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isMyVote
                                          ? FontWeight.w700
                                          : FontWeight.normal,
                                      color: AppTheme.textPrimary)),
                            ),
                            Text('${(pct * 100).toInt()}%',
                                style: const TextStyle(
                                    fontSize: 12, color: AppTheme.textHint)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _vote(int optionIdx, Map<String, dynamic> currentVotes) async {
    final ref = db
        .collection('chatRooms')
        .doc(roomId)
        .collection('messages')
        .doc(msgId);
    if (currentVotes[user.uid] == optionIdx) {
      await ref.update({'votes.${user.uid}': FieldValue.delete()});
    } else {
      await ref.update({'votes.${user.uid}': optionIdx});
    }
  }
}

// ── Poll Creator ──────────────────────────────────────────────────
class _PollCreator extends StatelessWidget {
  final TextEditingController question;
  final List<TextEditingController> options;
  final VoidCallback onAddOption;
  final VoidCallback onSend;
  final VoidCallback onClose;
  const _PollCreator({
    required this.question,
    required this.options,
    required this.onAddOption,
    required this.onSend,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Create Poll',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onClose),
            ],
          ),
          TextField(
            controller: question,
            decoration: const InputDecoration(
                labelText: 'Question', isDense: true),
          ),
          const SizedBox(height: 8),
          ...options.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: TextField(
                  controller: e.value,
                  decoration: InputDecoration(
                    labelText: 'Option ${e.key + 1}',
                    isDense: true,
                  ),
                ),
              )),
          Row(
            children: [
              TextButton.icon(
                onPressed: onAddOption,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add option'),
              ),
              const Spacer(),
              ElevatedButton(onPressed: onSend, child: const Text('Send Poll')),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Input Bar ─────────────────────────────────────────────────────
class _InputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onPoll;
  const _InputBar(
      {required this.ctrl,
      required this.sending,
      required this.onSend,
      required this.onPoll});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
      color: AppTheme.surface,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                decoration: InputDecoration(
                  hintText: 'Type a message…',
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  filled: true,
                  fillColor: AppTheme.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
                minLines: 1,
                maxLines: 4,
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 6),
            sending
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2)))
                : IconButton(
                    onPressed: onSend,
                    icon: const Icon(Icons.send_rounded),
                    color: AppTheme.navy,
                    iconSize: 24,
                  ),
          ],
        ),
      ),
    );
  }
}
