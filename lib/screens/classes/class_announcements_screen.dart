// lib/screens/classes/class_announcements_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../models/class_models.dart';
import '../../utils/app_theme.dart';

class ClassAnnouncementsScreen extends StatefulWidget {
  final ClassModel classModel;
  final UserModel user;
  const ClassAnnouncementsScreen(
      {super.key, required this.classModel, required this.user});

  @override
  State<ClassAnnouncementsScreen> createState() =>
      _ClassAnnouncementsScreenState();
}

class _ClassAnnouncementsScreenState
    extends State<ClassAnnouncementsScreen> {
  final _db = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final cls = widget.classModel;
    final user = widget.user;
    final canPost = user.canMentor || user.isAdmin;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Announcements · ${cls.shortname}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: canPost
          ? FloatingActionButton.extended(
              onPressed: () => _showPostSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('Post'),
              backgroundColor: Color(cls.colorValue),
            )
          : null,
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('classes')
            .doc(cls.id)
            .collection('announcements')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data!.docs
              .map((d) => ClassAnnouncementModel.fromMap(
                  d.data() as Map<String, dynamic>, d.id))
              .toList();

          if (items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.campaign_outlined,
                      size: 56, color: AppTheme.textTertiary),
                  SizedBox(height: 16),
                  Text('No announcements yet.',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 15)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _AnnouncementCard(
                ann: items[i], user: user, db: _db, cls: cls),
          );
        },
      ),
    );
  }

  void _showPostSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PostSheet(
          classModel: widget.classModel, user: widget.user, db: _db),
    );
  }
}

// ── Announcement Card ─────────────────────────────────────────────────────────

class _AnnouncementCard extends StatelessWidget {
  final ClassAnnouncementModel ann;
  final UserModel user;
  final FirebaseFirestore db;
  final ClassModel cls;
  const _AnnouncementCard(
      {required this.ann,
      required this.user,
      required this.db,
      required this.cls});

  @override
  Widget build(BuildContext context) {
    final canDelete = user.canMentor || user.isAdmin;
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor:
                      Color(cls.colorValue).withValues(alpha: 0.15),
                  child: Text(
                    ann.authorName.isNotEmpty
                        ? ann.authorName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(cls.colorValue)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ann.authorName,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary)),
                      Text(
                        DateFormat('MMM d, yyyy · h:mm a').format(ann.createdAt),
                        style: const TextStyle(
                            fontSize: 10, color: AppTheme.textTertiary),
                      ),
                    ],
                  ),
                ),
                if (ann.postedToGlobalFeed)
                  const Tooltip(
                    message: 'Also in Global Feed',
                    child: Icon(Icons.public,
                        size: 14, color: AppTheme.textTertiary),
                  ),
                if (canDelete)
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 16, color: Colors.red),
                    onPressed: () => _delete(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(ann.title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.navy)),
            if (ann.content.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(ann.content,
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textPrimary)),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Announcement?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await db
          .collection('classes')
          .doc(cls.id)
          .collection('announcements')
          .doc(ann.id)
          .delete();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
      }
    }
  }
}

// ── Post Sheet ────────────────────────────────────────────────────────────────

class _PostSheet extends StatefulWidget {
  final ClassModel classModel;
  final UserModel user;
  final FirebaseFirestore db;
  const _PostSheet(
      {required this.classModel, required this.user, required this.db});

  @override
  State<_PostSheet> createState() => _PostSheetState();
}

class _PostSheetState extends State<_PostSheet> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  bool _postToFeed = false;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{
        'classId': widget.classModel.id,
        'title': title,
        'content': _contentCtrl.text.trim(),
        'authorUid': widget.user.uid,
        'authorName': widget.user.displayName,
        'postedToGlobalFeed': _postToFeed,
        'commentCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      };
      await widget.db
          .collection('classes')
          .doc(widget.classModel.id)
          .collection('announcements')
          .add(data);

      if (_postToFeed) {
        // Also post to global feed
        await widget.db.collection('posts').add({
          ...data,
          'type': 'class_announcement',
          'className': widget.classModel.name,
        });
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: AppTheme.dividerColor,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Post Announcement',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.navy)),
          const SizedBox(height: 12),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
                labelText: 'Title *', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _contentCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
                labelText: 'Content', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Also post to Global Feed',
                style: TextStyle(fontSize: 13)),
            value: _postToFeed,
            onChanged: (v) => setState(() => _postToFeed = v),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _post,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.navy,
                  foregroundColor: Colors.white),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Post'),
            ),
          ),
        ],
      ),
    );
  }
}
