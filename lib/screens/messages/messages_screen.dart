// lib/screens/messages/messages_screen.dart
// Unified messaging: Group chats (Committee/Class/Other) + Personal
// - No Committee/Class tabs when creating new message
// - Intelligent search (prioritises first-letter name matches)
// - Messages sorted by recency
// - Students see only their class groups
// - Admin can create groups from messages tab with auto-created group chat
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
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int _groupUnread = 0;
  int _personalUnread = 0;
  int _lastTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.toLowerCase());
    });
    // Only rebuild when the tab index actually changes (not on every animation frame)
    _tabController.addListener(() {
      if (_tabController.indexIsChanging ||
          _tabController.index != _lastTabIndex) {
        _lastTabIndex = _tabController.index;
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                tabs: [
                  Tab(
                    child: _MsgTabLabel(
                      icon: Icons.school_outlined,
                      text: 'Groups',
                      unread: _groupUnread,
                    ),
                  ),
                  Tab(
                    child: _MsgTabLabel(
                      icon: Icons.chat_bubble_outline,
                      text: 'Personal',
                      unread: _personalUnread,
                    ),
                  ),
                ],
              ),
              // Intelligent search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search conversations…',
                    hintStyle: const TextStyle(fontSize: 13),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () => _searchCtrl.clear(),
                          )
                        : null,
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.15),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (_tabController.index == 0 && user.isAdmin)
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Create Group',
              onPressed: () => _showCreateGroupSheet(context, user),
            ),
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
          _GroupsTab(
            user: user,
            db: _db,
            searchQuery: _searchQuery,
            onUnreadChanged: (c) {
              if (mounted && c != _groupUnread) setState(() => _groupUnread = c);
            },
          ),
          _PersonalTab(
            user: user,
            db: _db,
            searchQuery: _searchQuery,
            onUnreadChanged: (c) {
              if (mounted && c != _personalUnread) setState(() => _personalUnread = c);
            },
          ),
        ],
      ),
    );
  }

  void _showCreateGroupSheet(BuildContext context, UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateGroupSheet(user: user, db: _db),
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

// ── Messages tab label with unread badge ──────────────────────────
class _MsgTabLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  final int unread;
  const _MsgTabLabel({required this.icon, required this.text, required this.unread});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12)),
        if (unread > 0) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: AppTheme.error,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              unread > 99 ? '99+' : '$unread',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Smart search ranking: starts-with first-letter > contains ──────
List<T> _rankBySearch<T>(
    List<T> items, String query, String Function(T) getName) {
  if (query.isEmpty) return items;
  final q = query.toLowerCase();

  // Group 1: name starts with query
  final starts = items.where((i) {
    final name = getName(i).toLowerCase();
    final parts = name.split(' ');
    return parts.any((p) => p.startsWith(q));
  }).toList();

  // Group 2: contains but not in group 1
  final contains = items
      .where((i) =>
          !starts.contains(i) &&
          getName(i).toLowerCase().contains(q))
      .toList();

  return [...starts, ...contains];
}

// ── GROUPS TAB ───────────────────────────────────────────────────
class _GroupsTab extends StatefulWidget {
  final UserModel user;
  final FirebaseFirestore db;
  final String searchQuery;
  final void Function(int count) onUnreadChanged;
  const _GroupsTab({
    required this.user,
    required this.db,
    required this.searchQuery,
    required this.onUnreadChanged,
  });
  @override
  State<_GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends State<_GroupsTab> {
  int _lastUnread = -1;

  void _notifyUnread(int count) {
    if (count != _lastUnread) {
      _lastUnread = count;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onUnreadChanged(count);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final db = widget.db;
    final searchQuery = widget.searchQuery;
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
        var docs = snap.data?.docs ?? [];

        // Students only see their classes
        if (user.isStudent) {
          docs = docs
              .where((d) =>
                  (d.data() as Map)['groupSubType'] == 'class')
              .toList();
        }

        // Sort by recency
        final sorted = [...docs];
        sorted.sort((a, b) {
          final aT = (a.data() as Map)['lastMessageAt'];
          final bT = (b.data() as Map)['lastMessageAt'];
          if (aT == null) return 1;
          if (bT == null) return -1;
          return (bT as Timestamp).compareTo(aT as Timestamp);
        });

        // Count total unread across all group rooms
        final totalUnread = sorted.fold<int>(0, (sum, d) {
          final unread = (d.data() as Map)['unread_${user.uid}'] as int? ?? 0;
          return sum + unread;
        });
        _notifyUnread(totalUnread);

        // Filter by search
        final filtered = _rankBySearch(
          sorted,
          searchQuery,
          (doc) => (doc.data() as Map)['name'] as String? ?? '',
        );

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.school_outlined,
                    size: 64, color: AppTheme.textHint),
                const SizedBox(height: 16),
                Text(
                  searchQuery.isNotEmpty
                      ? 'No groups match "$searchQuery"'
                      : 'No group chats yet',
                  style: const TextStyle(
                      fontSize: 15,
                      color: AppTheme.textSecondary),
                ),
                if (searchQuery.isEmpty && user.isAdmin) ...[
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Tap + above to create a committee, class, or other group chat.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppTheme.textHint, fontSize: 13),
                    ),
                  ),
                ]
              ],
            ),
          );
        }

        return Column(
          children: [
            if (user.isAdmin)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                color: AppTheme.navy.withValues(alpha: 0.06),
                child: Row(
                  children: [
                    const Icon(Icons.admin_panel_settings_outlined,
                        size: 16, color: AppTheme.navy),
                    const SizedBox(width: 8),
                    const Text('You manage these group chats',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.navy,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) =>
                            _CreateGroupSheet(user: user, db: db),
                      ),
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('New Group',
                          style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                          foregroundColor: AppTheme.navy,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8)),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: filtered.length,
                itemBuilder: (ctx, i) {
                  final d =
                      filtered[i].data() as Map<String, dynamic>;
                  final roomId = filtered[i].id;
                  final subType =
                      d['groupSubType'] as String? ?? 'committee';
                  return _RoomTile(
                    roomId: roomId,
                    data: d,
                    user: user,
                    db: db,
                    isCommitteeRoom: true,
                    groupSubType: subType,
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
class _PersonalTab extends StatefulWidget {
  final UserModel user;
  final FirebaseFirestore db;
  final String searchQuery;
  final void Function(int count) onUnreadChanged;
  const _PersonalTab({
    required this.user,
    required this.db,
    required this.searchQuery,
    required this.onUnreadChanged,
  });
  @override
  State<_PersonalTab> createState() => _PersonalTabState();
}

class _PersonalTabState extends State<_PersonalTab> {
  int _lastUnread = -1;

  void _notifyUnread(int count) {
    if (count != _lastUnread) {
      _lastUnread = count;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onUnreadChanged(count);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final db = widget.db;
    final searchQuery = widget.searchQuery;
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

        // Count total unread across personal rooms
        final totalUnread = sorted.fold<int>(0, (sum, d) {
          final unread = (d.data() as Map)['unread_${user.uid}'] as int? ?? 0;
          return sum + unread;
        });
        _notifyUnread(totalUnread);

        final filtered = _rankBySearch(
          sorted,
          searchQuery,
          (doc) => (doc.data() as Map)['name'] as String? ?? '',
        );

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline,
                    size: 64, color: AppTheme.textHint),
                const SizedBox(height: 16),
                Text(
                  searchQuery.isNotEmpty
                      ? 'No messages match "$searchQuery"'
                      : 'No personal messages yet',
                  style: const TextStyle(
                      fontSize: 15,
                      color: AppTheme.textSecondary),
                ),
                if (searchQuery.isEmpty && !user.isStudent)
                  const Text('Tap + to start a conversation',
                      style: TextStyle(
                          color: AppTheme.textHint, fontSize: 13)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: filtered.length,
          itemBuilder: (ctx, i) {
            final d = filtered[i].data() as Map<String, dynamic>;
            final roomId = filtered[i].id;
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
  final String groupSubType;
  const _RoomTile({
    required this.roomId,
    required this.data,
    required this.user,
    required this.db,
    required this.isCommitteeRoom,
    this.groupSubType = 'committee',
  });

  @override
  Widget build(BuildContext context) {
    final name = data['name'] as String? ?? 'Chat';
    final lastMsg = data['lastMessage'] as String? ?? '';
    final unread = data['unread_${user.uid}'] as int? ?? 0;
    final isGroup = data['isGroup'] as bool? ?? false;
    final lastAt = data['lastMessageAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(
            (data['lastMessageAt'] as Timestamp)
                .millisecondsSinceEpoch)
        : null;

    Color color;
    IconData icon;
    if (!isCommitteeRoom) {
      color = AppTheme.messagesColor;
      icon = isGroup ? Icons.group : Icons.person;
    } else {
      switch (groupSubType) {
        case 'class':
          color = AppTheme.navy;
          icon = Icons.school_outlined;
          break;
        case 'other':
          color = AppTheme.calendarColor;
          icon = Icons.group_work_outlined;
          break;
        default:
          color = const Color(0xFF7B1FA2);
          icon = Icons.groups_outlined;
      }
    }

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color, size: 22),
          ),
          if (unread > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                    color: AppTheme.error, shape: BoxShape.circle),
                child: Center(
                  child: Text('$unread',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ),
        ],
      ),
      title: Text(name,
          style: TextStyle(
              fontWeight:
                  unread > 0 ? FontWeight.w700 : FontWeight.w600,
              fontSize: 14)),
      subtitle: Text(lastMsg,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: unread > 0
                  ? AppTheme.textPrimary
                  : AppTheme.textHint,
              fontSize: 12,
              fontWeight: unread > 0
                  ? FontWeight.w500
                  : FontWeight.normal)),
      trailing: lastAt != null
          ? Text(_formatTime(lastAt),
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textHint))
          : null,
      onTap: () {
        db
            .collection('chatRooms')
            .doc(roomId)
            .update({'unread_${user.uid}': 0});
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
// Single-screen: group name + type chip + member checkboxes
// Auto-creates a group chat when a class/committee is created
class _CreateGroupSheet extends StatefulWidget {
  final UserModel user;
  final FirebaseFirestore db;
  const _CreateGroupSheet({required this.user, required this.db});

  @override
  State<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<_CreateGroupSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  final Set<String> _selectedUids = {};
  bool _loading = true;
  bool _saving = false;
  String _groupType = 'committee'; // committee | class | other

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchCtrl.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _searchCtrl.dispose();
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
    users.sort(
        (a, b) => (a['name'] as String).compareTo(b['name'] as String));
    if (mounted) {
      setState(() {
        _allUsers = users;
        _filteredUsers = users;
        _loading = false;
      });
    }
  }

  void _filterUsers() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredUsers = _rankBySearch(
        _allUsers,
        q,
        (u) => u['name'] as String,
      );
    });
  }

  Future<void> _create() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final allMembers = [widget.user.uid, ..._selectedUids];
      final allMemberNames = <String>[widget.user.displayName];
      for (final uid in _selectedUids) {
        final u = _allUsers.firstWhere((m) => m['uid'] == uid,
            orElse: () => {'name': uid});
        allMemberNames.add(u['name'] as String);
      }

      // Create chat room
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

      // Also create a group record in 'groups' collection for attendance
      if (_groupType == 'class' || _groupType == 'committee') {
        await widget.db.collection('groups').add({
          'name': _nameCtrl.text.trim(),
          'type': _groupType,
          'memberUids': allMembers,
          'mentorUids': [],
          'secondUids': [],
          'createdBy': widget.user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.97,
      minChildSize: 0.6,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: const Text('Create Group Chat',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Georgia')),
                  ),
                  TextButton(
                    onPressed: _saving ? null : _create,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2))
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
                  // Type selector — Committee | Class | Other
                  Row(
                    children: [
                      Expanded(
                        child: _TypeChip(
                          label: 'Committee',
                          icon: Icons.groups_outlined,
                          selected: _groupType == 'committee',
                          onTap: () =>
                              setState(() => _groupType = 'committee'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _TypeChip(
                          label: 'Class',
                          icon: Icons.school_outlined,
                          selected: _groupType == 'class',
                          onTap: () =>
                              setState(() => _groupType = 'class'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _TypeChip(
                          label: 'Other',
                          icon: Icons.group_work_outlined,
                          selected: _groupType == 'other',
                          onTap: () =>
                              setState(() => _groupType = 'other'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Group Name *',
                      hintText: _groupType == 'class'
                          ? 'e.g. Math 101'
                          : _groupType == 'committee'
                              ? 'e.g. Science Committee'
                              : 'e.g. Parent Helpers',
                      prefixIcon:
                          const Icon(Icons.group_work_outlined),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      prefixIcon: Icon(Icons.info_outline),
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Text('Add Members',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                      const Spacer(),
                      Text('${_selectedUids.length} selected',
                          style: const TextStyle(
                              color: AppTheme.textHint,
                              fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Search members
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search members…',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_loading)
                    const Center(child: CircularProgressIndicator())
                  else
                    ..._filteredUsers.map((u) {
                      final uid = u['uid'] as String;
                      final selected = _selectedUids.contains(uid);
                      final role = u['role'] as String;
                      return CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: selected,
                        onChanged: (v) {
                          setState(() {
                            if (v == true)
                              _selectedUids.add(uid);
                            else
                              _selectedUids.remove(uid);
                          });
                        },
                        secondary: CircleAvatar(
                          radius: 16,
                          backgroundColor:
                              AppTheme.navy.withValues(alpha: 0.1),
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
                            style:
                                const TextStyle(fontSize: 13)),
                        subtitle: Text(role,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textHint)),
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
          color:
              selected ? AppTheme.navy : AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? AppTheme.navy : AppTheme.cardBorder),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: selected
                    ? Colors.white
                    : AppTheme.textSecondary,
                size: 20),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: selected
                        ? Colors.white
                        : AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ── NEW PERSONAL CHAT SHEET ────────────────────────────────────────
// Unified: optional group name field + member list with checkboxes
// No separate Committee/Class tabs
class _NewPersonalChatSheet extends StatefulWidget {
  final UserModel user;
  final FirebaseFirestore db;
  const _NewPersonalChatSheet(
      {required this.user, required this.db});

  @override
  State<_NewPersonalChatSheet> createState() =>
      _NewPersonalChatSheetState();
}

class _NewPersonalChatSheetState extends State<_NewPersonalChatSheet> {
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  final Set<String> _selectedUids = {};
  final _groupNameCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _isGroupMode = false; // toggle between DM and group

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchCtrl.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _groupNameCtrl.dispose();
    _searchCtrl.dispose();
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
    users.sort(
        (a, b) => (a['name'] as String).compareTo(b['name'] as String));
    if (mounted) {
      setState(() {
        _allUsers = users;
        _filteredUsers = users;
        _loading = false;
      });
    }
  }

  void _filterUsers() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredUsers = _rankBySearch(
        _allUsers,
        q,
        (u) => u['name'] as String,
      );
    });
  }

  Future<void> _startDirect(String otherUid, String otherName) async {
    final snap = await widget.db
        .collection('chatRooms')
        .where('members', arrayContains: widget.user.uid)
        .where('roomType', isEqualTo: 'personal')
        .where('isGroup', isEqualTo: false)
        .get();
    String? existingId;
    for (final doc in snap.docs) {
      final members =
          List<String>.from(doc.data()['members'] as List? ?? []);
      if (members.contains(otherUid)) {
        existingId = doc.id;
        break;
      }
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
    if (_selectedUids.isEmpty) return;
    final groupName = _groupNameCtrl.text.trim();
    setState(() => _saving = true);
    try {
      final allMembers = [widget.user.uid, ..._selectedUids];
      final allNames = <String>[widget.user.displayName];
      for (final uid in _selectedUids) {
        final u = _allUsers.firstWhere((m) => m['uid'] == uid,
            orElse: () => {'name': uid});
        allNames.add(u['name'] as String);
      }
      // Auto-generate name from members if not provided
      final name = groupName.isNotEmpty
          ? groupName
          : allNames.take(3).join(', ');
      await widget.db.collection('chatRooms').add({
        'name': name,
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
      initialChildSize: 0.88,
      maxChildSize: 0.97,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: const Text('New Message',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Georgia')),
                  ),
                  if (_isGroupMode)
                    TextButton(
                      onPressed: _saving ? null : _createGroup,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2))
                          : const Text('Create'),
                    ),
                ],
              ),
            ),
            // Mode toggle
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _isGroupMode = false),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: !_isGroupMode
                              ? AppTheme.navy
                              : AppTheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Direct Message',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: !_isGroupMode
                                    ? Colors.white
                                    : AppTheme.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _isGroupMode = true),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _isGroupMode
                              ? AppTheme.navy
                              : AppTheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Group Chat',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: _isGroupMode
                                    ? Colors.white
                                    : AppTheme.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.all(16),
                children: [
                  // Optional group name (group mode only)
                  if (_isGroupMode) ...[
                    TextField(
                      controller: _groupNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Group Name (optional)',
                        hintText: 'Auto-generated from member names',
                        prefixIcon: Icon(Icons.group_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Member search
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: _isGroupMode
                          ? 'Search members to add…'
                          : 'Search people…',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_isGroupMode && _selectedUids.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                          '${_selectedUids.length} member(s) selected',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.navy,
                              fontWeight: FontWeight.w600)),
                    ),
                  if (_loading)
                    const Center(child: CircularProgressIndicator())
                  else
                    ..._filteredUsers.map((u) {
                      final uid = u['uid'] as String;
                      if (_isGroupMode) {
                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: _selectedUids.contains(uid),
                          onChanged: (v) {
                            setState(() {
                              if (v == true)
                                _selectedUids.add(uid);
                              else
                                _selectedUids.remove(uid);
                            });
                          },
                          secondary: CircleAvatar(
                            radius: 16,
                            backgroundColor:
                                AppTheme.messagesColor.withValues(
                                    alpha: 0.1),
                            child: Text(
                              (u['name'] as String).isNotEmpty
                                  ? (u['name'] as String)[0]
                                      .toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                  color: AppTheme.messagesColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12),
                            ),
                          ),
                          title: Text(u['name'] as String,
                              style:
                                  const TextStyle(fontSize: 13)),
                          subtitle: Text(u['role'] as String,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textHint)),
                        );
                      } else {
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor:
                                AppTheme.messagesColor.withValues(
                                    alpha: 0.1),
                            child: Text(
                              (u['name'] as String).isNotEmpty
                                  ? (u['name'] as String)[0]
                                      .toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                  color: AppTheme.messagesColor,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                          title: Text(u['name'] as String,
                              style:
                                  const TextStyle(fontSize: 14)),
                          subtitle: Text(u['role'] as String,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textHint)),
                          onTap: () => _startDirect(
                              uid, u['name'] as String),
                        );
                      }
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
    final doc = await widget.db
        .collection('chatRooms')
        .doc(widget.roomId)
        .get();
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
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700)),
            if (memberCount > 0)
              Text('$memberCount members',
                  style: const TextStyle(
                      fontSize: 11, color: Colors.white70)),
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
              onPressed: () =>
                  setState(() => _showPoll = !_showPoll),
            ),
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
                if (snap.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? [];
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollCtrl.hasClients) {
                    _scrollCtrl.jumpTo(
                        _scrollCtrl.position.maxScrollExtent);
                  }
                });
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final d =
                        docs[i].data() as Map<String, dynamic>;
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
      await widget.db
          .collection('chatRooms')
          .doc(widget.roomId)
          .update({
        'lastMessage': text,
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendPoll() async {
    final question = _pollQCtrl.text.trim();
    final opts = _pollOpts
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
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
    await widget.db
        .collection('chatRooms')
        .doc(widget.roomId)
        .update({
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
  State<_ManageMembersSheet> createState() =>
      _ManageMembersSheetState();
}

class _ManageMembersSheetState extends State<_ManageMembersSheet> {
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  late Set<String> _memberUids;
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _memberUids = Set<String>.from(
        (widget.roomData['members'] as List?)?.cast<String>() ?? []);
    _loadUsers();
    _searchCtrl.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
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
        .toList();
    users.sort(
        (a, b) => (a['name'] as String).compareTo(b['name'] as String));
    if (mounted) {
      setState(() {
        _allUsers = users;
        _filteredUsers = users;
        _loading = false;
      });
    }
  }

  void _filterUsers() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredUsers = _rankBySearch(
        _allUsers,
        q,
        (u) => u['name'] as String,
      );
    });
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
      await widget.db
          .collection('chatRooms')
          .doc(widget.roomId)
          .update({
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
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 8),
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
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2))
                        : const Text('Save'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search members…',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: ctrl,
                      padding: const EdgeInsets.all(8),
                      itemCount: _filteredUsers.length,
                      itemBuilder: (_, i) {
                        final u = _filteredUsers[i];
                        final uid = u['uid'] as String;
                        final isAdmin =
                            uid == widget.currentUser.uid;
                        return CheckboxListTile(
                          dense: true,
                          value: _memberUids.contains(uid),
                          onChanged: isAdmin
                              ? null
                              : (v) {
                                  setState(() {
                                    if (v == true)
                                      _memberUids.add(uid);
                                    else
                                      _memberUids.remove(uid);
                                  });
                                },
                          title: Text(u['name'] as String,
                              style:
                                  const TextStyle(fontSize: 13)),
                          subtitle: Text(
                              isAdmin
                                  ? 'Admin (always member)'
                                  : u['role'] as String,
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
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
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
                maxWidth:
                    MediaQuery.of(context).size.width * 0.72),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMe ? AppTheme.navy : AppTheme.surface,
              borderRadius: BorderRadius.circular(16).copyWith(
                bottomRight:
                    isMe ? const Radius.circular(4) : null,
                bottomLeft:
                    !isMe ? const Radius.circular(4) : null,
              ),
              border: isMe
                  ? null
                  : Border.all(color: AppTheme.cardBorder),
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
            padding:
                const EdgeInsets.only(top: 2, left: 8, right: 8),
            child: Text(DateFormat('h:mm a').format(createdAt),
                style: const TextStyle(
                    fontSize: 10, color: AppTheme.textHint)),
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
    final options =
        List<String>.from(data['options'] as List? ?? []);
    final votes =
        Map<String, dynamic>.from(data['votes'] as Map? ?? {});
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
              const Icon(Icons.poll_outlined,
                  size: 16, color: AppTheme.navy),
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
            final pct =
                totalVotes > 0 ? voteCount / totalVotes : 0.0;
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
                            color: AppTheme.navy
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10),
                        child: Row(
                          children: [
                            if (isMyVote)
                              const Icon(Icons.check_circle,
                                  size: 14, color: AppTheme.navy),
                            if (isMyVote)
                              const SizedBox(width: 4),
                            Expanded(
                              child: Text(opt,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isMyVote
                                          ? FontWeight.w700
                                          : FontWeight.normal,
                                      color:
                                          AppTheme.textPrimary)),
                            ),
                            Text('${(pct * 100).toInt()}%',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textHint)),
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

  Future<void> _vote(
      int optionIdx, Map<String, dynamic> currentVotes) async {
    final ref = db
        .collection('chatRooms')
        .doc(roomId)
        .collection('messages')
        .doc(msgId);
    if (currentVotes[user.uid] == optionIdx) {
      await ref.update(
          {'votes.${user.uid}': FieldValue.delete()});
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
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
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
              ElevatedButton(
                  onPressed: onSend,
                  child: const Text('Send Poll')),
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
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
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
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2)))
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
