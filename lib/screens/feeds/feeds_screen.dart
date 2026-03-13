// lib/screens/feeds/feeds_screen.dart
// Enhanced Feeds with Announcements / Social / Prayer tabs, likes, comments, polls
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../models/feed_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/app_theme.dart';

class FeedsScreen extends StatefulWidget {
  final int initialTab;
  const FeedsScreen({super.key, this.initialTab = 0});

  @override
  State<FeedsScreen> createState() => _FeedsScreenState();
}

class _FeedsScreenState extends State<FeedsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _firestoreService = FirestoreService();
  final _db = FirebaseFirestore.instance;

  // Per-tab last-seen timestamps (feeds sub-keys)
  int _announceTs = 0;
  int _socialTs = 0;
  int _prayerTs = 0;

  // Unread counts per tab (computed via StreamBuilders, shown in tab badges)
  int _announceCount = 0;
  int _socialCount = 0;
  int _prayerCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _loadLastSeen();
    // Mark current tab as seen when user switches to it
    _tabController.addListener(_onTabChanged);
  }

  Future<void> _loadLastSeen() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _announceTs = prefs.getInt('lastseen_feeds_announce') ?? 0;
        _socialTs   = prefs.getInt('lastseen_feeds_social')   ?? 0;
        _prayerTs   = prefs.getInt('lastseen_feeds_prayer')   ?? 0;
      });
      // Mark the initial tab as seen right away
      _markTabSeen(_tabController.index);
    }
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      _markTabSeen(_tabController.index);
    }
  }

  Future<void> _markTabSeen(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final ts = DateTime.now().millisecondsSinceEpoch;
    switch (index) {
      case 0:
        await prefs.setInt('lastseen_feeds_announce', ts);
        if (mounted) setState(() { _announceTs = ts; _announceCount = 0; });
        break;
      case 1:
        await prefs.setInt('lastseen_feeds_social', ts);
        if (mounted) setState(() { _socialTs = ts; _socialCount = 0; });
        break;
      case 2:
        await prefs.setInt('lastseen_feeds_prayer', ts);
        if (mounted) setState(() { _prayerTs = ts; _prayerCount = 0; });
        break;
    }
  }

  void _setCount(FeedType type, int count) {
    if (!mounted) return;
    // Only rebuild if the count actually changed
    final changed = switch (type) {
      FeedType.announcement => count != _announceCount,
      FeedType.social       => count != _socialCount,
      FeedType.prayer       => count != _prayerCount,
    };
    if (!changed) return;
    setState(() {
      switch (type) {
        case FeedType.announcement:
          _announceCount = count;
          break;
        case FeedType.social:
          _socialCount = count;
          break;
        case FeedType.prayer:
          _prayerCount = count;
          break;
      }
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser!;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Feeds'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: _TabLabel(
                icon: Icons.campaign_outlined,
                text: 'Announce',
                badgeCount: _announceCount,
              ),
            ),
            Tab(
              child: _TabLabel(
                icon: Icons.people_outline,
                text: 'Social',
                badgeCount: _socialCount,
              ),
            ),
            Tab(
              child: _TabLabel(
                icon: Icons.volunteer_activism_outlined,
                text: 'Prayer',
                badgeCount: _prayerCount,
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _FeedTab(
            type: FeedType.announcement, user: user, db: _db,
            lastSeenTs: _announceTs,
            onCountChanged: (c) => _setCount(FeedType.announcement, c),
          ),
          _FeedTab(
            type: FeedType.social, user: user, db: _db,
            lastSeenTs: _socialTs,
            onCountChanged: (c) => _setCount(FeedType.social, c),
          ),
          _FeedTab(
            type: FeedType.prayer, user: user, db: _db,
            lastSeenTs: _prayerTs,
            onCountChanged: (c) => _setCount(FeedType.prayer, c),
          ),
        ],
      ),
      floatingActionButton: _canPost(user, _currentType)
          ? FloatingActionButton(
              onPressed: () => _showCreateSheet(context, user),
              backgroundColor: AppTheme.feedsColor,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  FeedType get _currentType {
    switch (_tabController.index) {
      case 1:
        return FeedType.social;
      case 2:
        return FeedType.prayer;
      default:
        return FeedType.announcement;
    }
  }

  bool _canPost(UserModel user, FeedType type) {
    if (user.isStudent) return false;
    if (type == FeedType.announcement) return user.isAdmin;
    return true;
  }

  void _showCreateSheet(BuildContext context, UserModel user) {
    final type = _currentType;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreatePostSheet(type: type, user: user, db: _db),
    );
  }
}

// ── Tab label with badge ──────────────────────────────────────────
class _TabLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  final int badgeCount;
  const _TabLabel({required this.icon, required this.text, required this.badgeCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12)),
        if (badgeCount > 0) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: AppTheme.error,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              badgeCount > 99 ? '99+' : '$badgeCount',
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

// ── Per-Tab Feed List ─────────────────────────────────────────────
class _FeedTab extends StatefulWidget {
  final FeedType type;
  final UserModel user;
  final FirebaseFirestore db;
  final int lastSeenTs;
  final void Function(int count) onCountChanged;
  const _FeedTab({
    required this.type,
    required this.user,
    required this.db,
    required this.lastSeenTs,
    required this.onCountChanged,
  });

  @override
  State<_FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<_FeedTab> {
  // Track last reported count to avoid infinite setState loops
  int _lastReportedCount = -1;

  void _reportCount(int count) {
    if (count == _lastReportedCount) return; // no change — skip
    _lastReportedCount = count;
    // Schedule after build to avoid setState-during-build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onCountChanged(count);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: widget.db
          .collection('feeds')
          .where('type', isEqualTo: widget.type.name)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                const SizedBox(height: 12),
                Text('Error loading feed\n${snap.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              ],
            ),
          );
        }

        final docs = snap.data?.docs ?? [];
        // Sort in-memory: newest first
        final sorted = [...docs];
        sorted.sort((a, b) {
          final aT = (a.data() as Map)['createdAt'];
          final bT = (b.data() as Map)['createdAt'];
          if (aT == null) return 1;
          if (bT == null) return -1;
          final aMs = (aT as Timestamp).millisecondsSinceEpoch;
          final bMs = (bT as Timestamp).millisecondsSinceEpoch;
          return bMs.compareTo(aMs);
        });

        // Calculate unread count — only notify parent when value changes
        if (widget.lastSeenTs > 0) {
          final unread = sorted.where((d) {
            final ts = (d.data() as Map)['createdAt'];
            if (ts == null) return false;
            return (ts as Timestamp).millisecondsSinceEpoch > widget.lastSeenTs;
          }).length;
          _reportCount(unread);
        } else {
          _reportCount(0);
        }

        if (sorted.isEmpty) {
          return _EmptyFeed(type: widget.type);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sorted.length,
          itemBuilder: (ctx, i) {
            final data = sorted[i].data() as Map<String, dynamic>;
            final post = FeedModel.fromMap(data, sorted[i].id);
            return _PostCard(post: post, user: widget.user, db: widget.db);
          },
        );
      },
    );
  }
}

// ── Post Card ─────────────────────────────────────────────────────
class _PostCard extends StatelessWidget {
  final FeedModel post;
  final UserModel user;
  final FirebaseFirestore db;
  const _PostCard({required this.post, required this.user, required this.db});

  @override
  Widget build(BuildContext context) {
    final isLiked = post.likedBy.contains(user.uid);
    final typeColor = _typeColor(post.type);
    final inStudentFeed = post.inKidFeed;  // inKidFeed field stores inStudentFeed

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
        [
          // Student feed indicator
          if (inStudentFeed)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.gold.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.star, size: 12, color: AppTheme.gold),
                  SizedBox(width: 5),
                  Text('Also in Student Feed',
                      style: TextStyle(fontSize: 11, color: AppTheme.gold, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: typeColor.withValues(alpha: 0.12),
                  child: Text(
                    post.authorName.isNotEmpty ? post.authorName[0].toUpperCase() : '?',
                    style: TextStyle(color: typeColor, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.authorName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppTheme.textPrimary)),
                      Text(
                        _timeAgo(post.createdAt),
                        style: const TextStyle(fontSize: 11, color: AppTheme.textHint),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _typeLabel(post.type),
                    style: TextStyle(
                        color: typeColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5),
                  ),
                ),
                if ((user.isAdmin || user.uid == post.authorId) && !user.isStudent)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18, color: AppTheme.textHint),
                    onSelected: (v) {
                      if (v == 'delete') _deletePost(context);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.title.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(post.title,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            fontFamily: 'Georgia')),
                  ),
                Text(post.content,
                    style: const TextStyle(
                        fontSize: 14, color: AppTheme.textSecondary, height: 1.5)),
              ],
            ),
          ),

          // Attachment
          if (post.attachmentUrl != null && post.attachmentUrl!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: InkWell(
                onTap: () async {
                  // URL launcher is already imported
                  final url = Uri.parse(post.attachmentUrl!);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.navy.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.navy.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.attach_file,
                          size: 16, color: AppTheme.navy),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          post.attachmentName ?? 'Attachment',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.navy,
                              decoration: TextDecoration.underline),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.open_in_new,
                          size: 14, color: AppTheme.textHint),
                    ],
                  ),
                ),
              ),
            ),
          // Poll
          if (post.pollOptions.isNotEmpty)
            _PollWidget(post: post, user: user, db: db),

          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Row(
              children: [
                _ActionButton(
                  icon: isLiked ? Icons.favorite : Icons.favorite_border,
                  label: '${post.likedBy.length}',
                  color: isLiked ? Colors.red : AppTheme.textHint,
                  onTap: () => _toggleLike(context),
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  icon: Icons.chat_bubble_outline,
                  label: '${post.commentCount}',
                  color: AppTheme.textHint,
                  onTap: () => _openComments(context),
                ),
                const Spacer(),
                if (post.type == FeedType.prayer)
                  TextButton.icon(
                    onPressed: () => _toggleLike(context),
                    icon: const Icon(Icons.volunteer_activism, size: 16, color: AppTheme.prayerColor),
                    label: const Text('Pray', style: TextStyle(color: AppTheme.prayerColor, fontSize: 12)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toggleLike(BuildContext context) {
    final ref = db.collection('feeds').doc(post.id);
    if (post.likedBy.contains(user.uid)) {
      ref.update({'likedBy': FieldValue.arrayRemove([user.uid])});
    } else {
      ref.update({'likedBy': FieldValue.arrayUnion([user.uid])});
    }
  }

  void _deletePost(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () {
              db.collection('feeds').doc(post.id).delete();
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _openComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsSheet(post: post, user: user, db: db),
    );
  }

  Color _typeColor(FeedType t) {
    switch (t) {
      case FeedType.announcement:
        return AppTheme.navy;
      case FeedType.social:
        return AppTheme.calendarColor;
      case FeedType.prayer:
        return AppTheme.prayerColor;
    }
  }

  String _typeLabel(FeedType t) {
    switch (t) {
      case FeedType.announcement:
        return 'ANNOUNCE';
      case FeedType.social:
        return 'SOCIAL';
      case FeedType.prayer:
        return 'PRAYER';
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }
}

// ── Poll Widget ───────────────────────────────────────────────────
class _PollWidget extends StatelessWidget {
  final FeedModel post;
  final UserModel user;
  final FirebaseFirestore db;
  const _PollWidget({required this.post, required this.user, required this.db});

  @override
  Widget build(BuildContext context) {
    final totalVotes = post.pollVotes.values.fold<int>(0, (s, e) => s + (e as int? ?? 0));
    final hasVoted = post.pollVotes.keys.any((k) => k.startsWith('${user.uid}_'));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('POLL', style: TextStyle(
              color: AppTheme.gold, fontSize: 10,
              fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          ...post.pollOptions.asMap().entries.map((e) {
            final idx = e.key;
            final opt = e.value;
            final votes = post.pollVotes['option_$idx'] as int? ?? 0;
            final pct = totalVotes > 0 ? votes / totalVotes : 0.0;

            return GestureDetector(
              onTap: hasVoted ? null : () => _vote(idx),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.cardBorder),
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
                          color: AppTheme.navy.withValues(alpha: 0.1),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(child: Text(opt, style: const TextStyle(fontSize: 13))),
                          if (hasVoted)
                            Text('${(pct * 100).round()}%',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
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

  void _vote(int optionIndex) {
    db.collection('feeds').doc(post.id).update({
      'pollVotes.option_$optionIndex': FieldValue.increment(1),
      'pollVotes.${user.uid}_voted': true,
    });
  }
}

// ── Comments Sheet ────────────────────────────────────────────────
class _CommentsSheet extends StatefulWidget {
  final FeedModel post;
  final UserModel user;
  final FirebaseFirestore db;
  const _CommentsSheet({required this.post, required this.user, required this.db});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      minChildSize: 0.35,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppTheme.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Comments',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: widget.db
                    .collection('feeds')
                    .doc(widget.post.id)
                    .collection('comments')
                    .orderBy('createdAt', descending: false)
                    .snapshots(),
                builder: (ctx, snap) {
                  final docs = snap.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(
                      child: Text('No comments yet. Be the first!',
                          style: TextStyle(color: AppTheme.textHint)),
                    );
                  }
                  return ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    itemBuilder: (_, i) {
                      final d = docs[i].data() as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AppTheme.navy.withValues(alpha: 0.1),
                              child: Text(
                                (d['authorName'] as String? ?? '?')[0].toUpperCase(),
                                style: const TextStyle(
                                    color: AppTheme.navy, fontSize: 13,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(d['authorName'] as String? ?? '',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                  const SizedBox(height: 3),
                                  Text(d['content'] as String? ?? '',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: AppTheme.textSecondary)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            if (!widget.user.isStudent) ...[
              const Divider(height: 1),
              if (widget.post.inKidFeed)
                Container(
                  color: AppTheme.gold.withValues(alpha: 0.08),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: const [
                      Icon(Icons.star, size: 13, color: AppTheme.gold),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'These comments appear in students\' feeds',
                          style: TextStyle(fontSize: 11, color: AppTheme.gold, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: EdgeInsets.only(
                  left: 16, right: 16, top: 10,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        decoration: const InputDecoration(
                          hintText: 'Add a comment…',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        maxLines: 2,
                        minLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: _sending
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send, color: AppTheme.navy),
                      onPressed: _sending ? null : _sendComment,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _sendComment() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final ref = widget.db
          .collection('feeds')
          .doc(widget.post.id)
          .collection('comments');
      await ref.add({
        'authorId': widget.user.uid,
        'authorName': widget.user.displayName,
        'content': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await widget.db.collection('feeds').doc(widget.post.id).update({
        'commentCount': FieldValue.increment(1),
      });
      _ctrl.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

// ── Create Post Sheet ─────────────────────────────────────────────
class _CreatePostSheet extends StatefulWidget {
  final FeedType type;
  final UserModel user;
  final FirebaseFirestore db;
  const _CreatePostSheet({required this.type, required this.user, required this.db});

  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  bool _isPoll = false;
  bool _inStudentFeed = false;
  final List<TextEditingController> _pollOptions = [
    TextEditingController(),
    TextEditingController(),
  ];
  bool _saving = false;
  String? _attachmentUrl;
  String? _attachmentName;
  bool _uploadingFile = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    for (final c in _pollOptions) c.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;
    setState(() => _uploadingFile = true);
    try {
      final ext = file.extension ?? 'bin';
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final ref = FirebaseStorage.instance.ref().child('attachments/$fileName');
      final task = await ref.putData(bytes);
      final url = await task.ref.getDownloadURL();
      setState(() {
        _attachmentUrl = url;
        _attachmentName = file.name ?? fileName;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: AppTheme.error));
      }
    } finally {
      if (mounted) setState(() => _uploadingFile = false);
    }
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'New ${_typeLabel(widget.type)} Post',
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                    labelText: 'Title (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contentCtrl,
                decoration: const InputDecoration(
                    labelText: 'Content',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder()),
                maxLines: 4,
                minLines: 3,
              ),
              const SizedBox(height: 12),
              // File attachment
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _uploadingFile ? null : _pickAttachment,
                    icon: _uploadingFile
                        ? const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.attach_file, size: 16),
                    label: Text(_attachmentName != null
                        ? _attachmentName!
                        : 'Attach File'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.navy,
                      side: BorderSide(color: AppTheme.navy.withValues(alpha: 0.4)),
                    ),
                  ),
                  if (_attachmentUrl != null)
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: AppTheme.error),
                      onPressed: () => setState(() {
                        _attachmentUrl = null;
                        _attachmentName = null;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Add Poll'),
                value: _isPoll,
                activeThumbColor: AppTheme.navy,
                onChanged: (v) => setState(() => _isPoll = v),
              ),
              if (_isPoll) ...[
                ..._pollOptions.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: e.value,
                    decoration: InputDecoration(
                      labelText: 'Option ${e.key + 1}',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                )),
                TextButton.icon(
                  onPressed: () => setState(
                      () => _pollOptions.add(TextEditingController())),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Option'),
                ),
              ],
              if (widget.type == FeedType.announcement || widget.type == FeedType.social)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Also post to Student Feed'),
                  subtitle: const Text('Default: OFF', style: TextStyle(fontSize: 11, color: AppTheme.textHint)),
                  value: _inStudentFeed,
                  activeThumbColor: AppTheme.navy,
                  onChanged: (v) => setState(() => _inStudentFeed = v),
                ),
              if (widget.type == FeedType.prayer)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show in Students\' Feed'),
                  value: _inStudentFeed,
                  activeThumbColor: AppTheme.navy,
                  onChanged: (v) => setState(() => _inStudentFeed = v),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.navy,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _saving
                      ? const CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2)
                      : const Text('Post'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_contentCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);

    final pollOptions = _isPoll
        ? _pollOptions.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList()
        : <String>[];

    try {
      await widget.db.collection('feeds').add({
        'type': widget.type.name,
        'title': _titleCtrl.text.trim(),
        'content': _contentCtrl.text.trim(),
        'authorId': widget.user.uid,
        'authorName': widget.user.displayName,
        'likedBy': [],
        'commentCount': 0,
        'pollOptions': pollOptions,
        'pollVotes': {},
        'inKidFeed': _inStudentFeed,
        'inStudentFeed': _inStudentFeed,
        'attachmentUrl': _attachmentUrl,
        'attachmentName': _attachmentName,
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

  String _typeLabel(FeedType t) {
    switch (t) {
      case FeedType.announcement:
        return 'Announcement';
      case FeedType.social:
        return 'Social';
      case FeedType.prayer:
        return 'Prayer Request';
    }
  }
}

// ── Action Button Helper ──────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, color: color)),
          ],
        ),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────
class _EmptyFeed extends StatelessWidget {
  final FeedType type;
  const _EmptyFeed({required this.type});

  @override
  Widget build(BuildContext context) {
    final icon = type == FeedType.announcement
        ? Icons.campaign_outlined
        : type == FeedType.prayer
            ? Icons.volunteer_activism_outlined
            : Icons.people_outline;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppTheme.textHint),
          const SizedBox(height: 16),
          Text(
            type == FeedType.prayer
                ? 'No prayer requests yet'
                : type == FeedType.announcement
                    ? 'No announcements yet'
                    : 'No social posts yet',
            style: const TextStyle(
                fontSize: 16, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text('Be the first to post!',
              style: TextStyle(color: AppTheme.textHint)),
        ],
      ),
    );
  }
}
