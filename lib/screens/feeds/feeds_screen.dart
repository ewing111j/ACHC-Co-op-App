// lib/screens/feeds/feeds_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../models/feed_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/app_theme.dart';
import 'package:uuid/uuid.dart';

class FeedsScreen extends StatefulWidget {
  const FeedsScreen({super.key});

  @override
  State<FeedsScreen> createState() => _FeedsScreenState();
}

class _FeedsScreenState extends State<FeedsScreen> {
  final _firestoreService = FirestoreService();
  final _uuid = const Uuid();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser!;
    final familyId = user.familyId ?? '';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Feeds'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<List<FeedModel>>(
        stream: _firestoreService.streamFeeds(familyId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final feeds = snapshot.data ?? [];

          if (feeds.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.dynamic_feed_outlined,
                      size: 64, color: AppTheme.textHint),
                  const SizedBox(height: 16),
                  const Text(
                    'No posts yet',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  const Text('Share news and announcements',
                      style: TextStyle(color: AppTheme.textHint)),
                  if (user.isParent || user.isAdmin) ...[
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () =>
                          _showCreatePostDialog(context, user, familyId),
                      icon: const Icon(Icons.create),
                      label: const Text('Create Post'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.feedsColor),
                    ),
                  ],
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: feeds.length,
            itemBuilder: (ctx, i) =>
                _buildFeedCard(ctx, feeds[i], user.uid),
          );
        },
      ),
      floatingActionButton: (user.isParent || user.isAdmin)
          ? FloatingActionButton(
              onPressed: () =>
                  _showCreatePostDialog(context, user, familyId),
              backgroundColor: AppTheme.feedsColor,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildFeedCard(
      BuildContext context, FeedModel feed, String currentUserId) {
    final typeInfo = _getFeedTypeInfo(feed.type);
    final isLiked = feed.likes.contains(currentUserId);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: typeInfo.color.withValues(alpha: 0.15),
                  child: Icon(typeInfo.icon,
                      color: typeInfo.color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feed.authorName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      Text(
                        DateFormat('MMM d · h:mm a')
                            .format(feed.createdAt),
                        style: const TextStyle(
                            color: AppTheme.textHint, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: typeInfo.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(typeInfo.icon,
                          size: 12, color: typeInfo.color),
                      const SizedBox(width: 3),
                      Text(
                        typeInfo.label,
                        style: TextStyle(
                            color: typeInfo.color,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                if (feed.isPinned) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.push_pin,
                      size: 16, color: AppTheme.warning),
                ],
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feed.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  feed.content,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),

          // Image
          if (feed.imageUrl != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(12)),
              child: Image.network(
                feed.imageUrl!,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, st) => const SizedBox.shrink(),
              ),
            ),
          ],

          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? AppTheme.error : AppTheme.textHint,
                    size: 20,
                  ),
                  onPressed: () => _firestoreService.toggleLike(
                      feed.id, currentUserId),
                ),
                Text(
                  '${feed.likes.length}',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.comment_outlined,
                    size: 20, color: AppTheme.textHint),
                const SizedBox(width: 4),
                Text(
                  '${feed.commentCount}',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _FeedTypeInfo _getFeedTypeInfo(FeedType type) {
    switch (type) {
      case FeedType.news:
        return _FeedTypeInfo(Icons.newspaper, AppTheme.info, 'News');
      case FeedType.event:
        return _FeedTypeInfo(
            Icons.event, AppTheme.calendarColor, 'Event');
      case FeedType.photo:
        return _FeedTypeInfo(Icons.photo, AppTheme.photosColor, 'Photo');
      case FeedType.resource:
        return _FeedTypeInfo(
            Icons.link, AppTheme.filesColor, 'Resource');
      default:
        return _FeedTypeInfo(
            Icons.campaign, AppTheme.feedsColor, 'Announcement');
    }
  }

  void _showCreatePostDialog(
      BuildContext context, user, String familyId) {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    final imageCtrl = TextEditingController();
    FeedType selectedType = FeedType.announcement;
    bool isPinned = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Create Post'),
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
                  controller: contentCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Content'),
                  maxLines: 4,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: imageCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Image URL (optional)',
                    hintText: 'https://...',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<FeedType>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: FeedType.values
                      .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t.name.toUpperCase())))
                      .toList(),
                  onChanged: (v) => setDialogState(
                      () => selectedType = v ?? FeedType.announcement),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Pin this post'),
                  value: isPinned,
                  onChanged: (v) =>
                      setDialogState(() => isPinned = v ?? false),
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
                if (titleCtrl.text.isEmpty ||
                    contentCtrl.text.isEmpty) return;
                final feed = FeedModel(
                  id: _uuid.v4(),
                  title: titleCtrl.text.trim(),
                  content: contentCtrl.text.trim(),
                  type: selectedType,
                  authorId: user.uid,
                  authorName: user.displayName,
                  familyId: familyId,
                  createdAt: DateTime.now(),
                  imageUrl: imageCtrl.text.trim().isEmpty
                      ? null
                      : imageCtrl.text.trim(),
                  isPinned: isPinned,
                );
                await _firestoreService.createFeed(feed);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.feedsColor),
              child: const Text('Post'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedTypeInfo {
  final IconData icon;
  final Color color;
  final String label;

  _FeedTypeInfo(this.icon, this.color, this.label);
}
