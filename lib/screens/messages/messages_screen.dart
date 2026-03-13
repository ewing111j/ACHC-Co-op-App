// lib/screens/messages/messages_screen.dart
// Real-time individual/group chat via Firebase + poll capability
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
            Tab(icon: Icon(Icons.group_outlined, size: 18), text: 'Groups'),
            Tab(icon: Icon(Icons.person_outline, size: 18), text: 'Direct'),
          ],
        ),
        actions: [
          if (!user.isKid)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'New Chat',
              onPressed: () => _showNewChat(context, user),
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ChatRoomList(user: user, db: _db, isGroup: true),
          _ChatRoomList(user: user, db: _db, isGroup: false),
        ],
      ),
    );
  }

  void _showNewChat(BuildContext context, UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewChatSheet(user: user, db: _db),
    );
  }
}

// ── Chat Room List ────────────────────────────────────────────────
class _ChatRoomList extends StatelessWidget {
  final UserModel user;
  final FirebaseFirestore db;
  final bool isGroup;
  const _ChatRoomList({required this.user, required this.db, required this.isGroup});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db
          .collection('chatRooms')
          .where('members', arrayContains: user.uid)
          .where('isGroup', isEqualTo: isGroup)
          .orderBy('lastMessageAt', descending: true)
          .snapshots(),
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
                Icon(
                  isGroup ? Icons.group_outlined : Icons.chat_bubble_outline,
                  size: 64, color: AppTheme.textHint,
                ),
                const SizedBox(height: 16),
                Text(
                  isGroup ? 'No group chats yet' : 'No direct messages yet',
                  style: const TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                const Text('Tap + to start a new conversation',
                    style: TextStyle(color: AppTheme.textHint)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final roomId = docs[i].id;
            final name = d['name'] as String? ?? 'Chat';
            final lastMsg = d['lastMessage'] as String? ?? '';
            final unread = d['unread_${user.uid}'] as int? ?? 0;
            final lastAt = d['lastMessageAt'] != null
                ? DateTime.fromMillisecondsSinceEpoch(
                    (d['lastMessageAt'] as Timestamp).millisecondsSinceEpoch)
                : DateTime.now();

            return _RoomTile(
              roomId: roomId,
              name: name,
              lastMessage: lastMsg,
              unreadCount: unread,
              lastAt: lastAt,
              isGroup: isGroup,
              user: user,
              db: db,
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
  final String name;
  final String lastMessage;
  final int unreadCount;
  final DateTime lastAt;
  final bool isGroup;
  final UserModel user;
  final FirebaseFirestore db;
  const _RoomTile({
    required this.roomId,
    required this.name,
    required this.lastMessage,
    required this.unreadCount,
    required this.lastAt,
    required this.isGroup,
    required this.user,
    required this.db,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: AppTheme.messagesColor.withValues(alpha: 0.12),
        child: Icon(
          isGroup ? Icons.group : Icons.person,
          color: AppTheme.messagesColor, size: 22,
        ),
      ),
      title: Text(name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(lastMessage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppTheme.textHint, fontSize: 12)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(_formatTime(lastAt),
              style: const TextStyle(fontSize: 11, color: AppTheme.textHint)),
          if (unreadCount > 0) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.navy,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$unreadCount',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
      onTap: () {
        // Clear unread
        db.collection('chatRooms').doc(roomId).update({'unread_${user.uid}': 0});
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              roomId: roomId,
              roomName: name,
              user: user,
              db: db,
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

// ── Chat Screen ───────────────────────────────────────────────────
class ChatScreen extends StatefulWidget {
  final String roomId;
  final String roomName;
  final UserModel user;
  final FirebaseFirestore db;
  const ChatScreen({
    super.key,
    required this.roomId,
    required this.roomName,
    required this.user,
    required this.db,
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

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _pollQCtrl.dispose();
    for (final c in _pollOpts) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(widget.roomName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!widget.user.isKid)
            IconButton(
              icon: const Icon(Icons.poll_outlined),
              tooltip: 'Create Poll',
              onPressed: () => setState(() => _showPoll = !_showPoll),
            ),
        ],
      ),
      body: Column(
        children: [
          // Messages
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

          // Poll creator
          if (_showPoll && !widget.user.isKid)
            _PollCreator(
              question: _pollQCtrl,
              options: _pollOpts,
              onAddOption: () => setState(() => _pollOpts.add(TextEditingController())),
              onSend: _sendPoll,
              onClose: () => setState(() => _showPoll = false),
            ),

          // Input bar
          if (!widget.user.isKid)
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
      final ref = widget.db
          .collection('chatRooms')
          .doc(widget.roomId)
          .collection('messages');
      await ref.add({
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
    final opts = _pollOpts.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
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
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 2),
              child: Text(data['senderName'] as String? ?? '',
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textHint, fontWeight: FontWeight.w600)),
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
                fontSize: 14, height: 1.4,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 8, right: 8),
            child: Text(
              DateFormat('h:mm a').format(createdAt),
              style: const TextStyle(fontSize: 10, color: AppTheme.textHint),
            ),
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
    final totalVotes = votes.values
        .where((v) => v is int)
        .fold<int>(0, (s, v) => s + (v as int));
    final hasVoted = votes.containsKey(user.uid);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.poll_outlined, size: 16, color: AppTheme.gold),
              const SizedBox(width: 6),
              const Text('Poll', style: TextStyle(
                  color: AppTheme.gold, fontSize: 11,
                  fontWeight: FontWeight.w700, letterSpacing: 0.8)),
              const SizedBox(width: 8),
              Text(data['senderName'] as String? ?? '',
                  style: const TextStyle(color: AppTheme.textHint, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),
          Text(question, style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 10),
          ...options.asMap().entries.map((e) {
            final idx = e.key;
            final opt = e.value;
            final voteCount = votes['option_$idx'] as int? ?? 0;
            final pct = totalVotes > 0 ? voteCount / totalVotes : 0.0;
            final userVoted = votes[user.uid] == idx;

            return GestureDetector(
              onTap: hasVoted ? null : () => _vote(idx, votes),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: userVoted ? AppTheme.navy : AppTheme.cardBorder),
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    if (hasVoted)
                      FractionallySizedBox(
                        widthFactor: pct,
                        child: Container(
                          height: 38,
                          color: AppTheme.navy.withValues(alpha: 0.08),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          if (userVoted)
                            const Icon(Icons.check_circle, size: 14, color: AppTheme.navy),
                          if (userVoted) const SizedBox(width: 6),
                          Expanded(
                            child: Text(opt, style: const TextStyle(fontSize: 13)),
                          ),
                          if (hasVoted)
                            Text('${(pct * 100).round()}%',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600,
                                    color: AppTheme.navy)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          Text('$totalVotes vote${totalVotes != 1 ? 's' : ''}',
              style: const TextStyle(fontSize: 11, color: AppTheme.textHint)),
        ],
      ),
    );
  }

  void _vote(int optionIndex, Map<String, dynamic> currentVotes) {
    final ref = db
        .collection('chatRooms')
        .doc(roomId)
        .collection('messages')
        .doc(msgId);
    ref.update({
      'votes.option_$optionIndex': FieldValue.increment(1),
      'votes.${user.uid}': optionIndex,
    });
  }
}

// ── Input Bar ─────────────────────────────────────────────────────
class _InputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onPoll;
  const _InputBar({
    required this.ctrl,
    required this.sending,
    required this.onSend,
    required this.onPoll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16, right: 8, top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: const Border(top: BorderSide(color: AppTheme.cardBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                hintText: 'Type a message…',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              maxLines: 4,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.send_rounded, color: AppTheme.navy),
            onPressed: sending ? null : onSend,
          ),
        ],
      ),
    );
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
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        border: const Border(top: BorderSide(color: AppTheme.cardBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('Create Poll',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: AppTheme.navy)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close, size: 18), onPressed: onClose),
            ],
          ),
          TextField(
            controller: question,
            decoration: const InputDecoration(
                labelText: 'Question', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          ...options.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: TextField(
              controller: e.value,
              decoration: InputDecoration(
                labelText: 'Option ${e.key + 1}',
                border: const OutlineInputBorder(),
              ),
            ),
          )),
          Row(
            children: [
              TextButton.icon(
                onPressed: onAddOption,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Option'),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: onSend,
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.navy),
                child: const Text('Send Poll'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── New Chat Sheet ────────────────────────────────────────────────
class _NewChatSheet extends StatefulWidget {
  final UserModel user;
  final FirebaseFirestore db;
  const _NewChatSheet({required this.user, required this.db});

  @override
  State<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<_NewChatSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _nameCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          const Text('New Chat',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          TabBar(
            controller: _tab,
            labelColor: AppTheme.navy,
            unselectedLabelColor: AppTheme.textHint,
            indicatorColor: AppTheme.gold,
            dividerColor: AppTheme.cardBorder,
            tabs: const [Tab(text: 'Group Chat'), Tab(text: 'Direct Message')],
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Chat Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _createRoom,
                    child: _saving
                        ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        : const Text('Create'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createRoom() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.db.collection('chatRooms').add({
        'name': _nameCtrl.text.trim(),
        'isGroup': _tab.index == 0,
        'members': [widget.user.uid],
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
}
