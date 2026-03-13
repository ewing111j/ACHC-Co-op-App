// lib/screens/photos/photos_screen.dart
// Shared album, uploads, likes/comments, stored in Firebase Storage
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../utils/app_theme.dart';

class PhotosScreen extends StatefulWidget {
  const PhotosScreen({super.key});

  @override
  State<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends State<PhotosScreen> {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _picker = ImagePicker();
  bool _uploading = false;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser!;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Photos'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('photos')
            .orderBy('createdAt', descending: true)
            .limit(60)
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
                  const Icon(Icons.photo_library_outlined,
                      size: 64, color: AppTheme.textHint),
                  const SizedBox(height: 16),
                  const Text('No photos yet',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  const Text('Share memories with your community',
                      style: TextStyle(color: AppTheme.textHint)),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              return _PhotoTile(
                photoId: docs[i].id,
                data: d,
                user: user,
                db: _db,
              );
            },
          );
        },
      ),
      floatingActionButton: !user.isKid
          ? FloatingActionButton(
              onPressed: _uploading ? null : () => _uploadPhoto(context, user),
              backgroundColor: AppTheme.photosColor,
              child: _uploading
                  ? const CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2)
                  : const Icon(Icons.add_a_photo),
            )
          : null,
    );
  }

  Future<void> _uploadPhoto(BuildContext context, UserModel user) async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      final file = File(picked.path);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('photos/$fileName');
      final task = await ref.putFile(file);
      final url = await task.ref.getDownloadURL();

      await _db.collection('photos').add({
        'url': url,
        'thumbnailUrl': url,
        'uploadedBy': user.uid,
        'uploaderName': user.displayName,
        'likedBy': [],
        'commentCount': 0,
        'caption': '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo uploaded!'),
              backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'),
              backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }
}

// ── Photo Tile ────────────────────────────────────────────────────
class _PhotoTile extends StatelessWidget {
  final String photoId;
  final Map<String, dynamic> data;
  final UserModel user;
  final FirebaseFirestore db;
  const _PhotoTile({
    required this.photoId,
    required this.data,
    required this.user,
    required this.db,
  });

  @override
  Widget build(BuildContext context) {
    final url = data['url'] as String? ?? '';
    final likedBy = List<String>.from(data['likedBy'] as List? ?? []);
    final isLiked = likedBy.contains(user.uid);
    final likeCount = likedBy.length;

    return GestureDetector(
      onTap: () => _openPhoto(context),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            url,
            fit: BoxFit.cover,
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : Container(
                    color: AppTheme.surfaceVariant,
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 1)),
                  ),
            errorBuilder: (_, __, ___) => Container(
              color: AppTheme.surfaceVariant,
              child: const Icon(Icons.broken_image, color: AppTheme.textHint),
            ),
          ),
          Positioned(
            bottom: 4, right: 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _toggleLike(isLiked),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          size: 12,
                          color: isLiked ? Colors.red : Colors.white,
                        ),
                        const SizedBox(width: 3),
                        Text('$likeCount',
                            style: const TextStyle(color: Colors.white, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toggleLike(bool isLiked) {
    final ref = db.collection('photos').doc(photoId);
    if (isLiked) {
      ref.update({'likedBy': FieldValue.arrayRemove([user.uid])});
    } else {
      ref.update({'likedBy': FieldValue.arrayUnion([user.uid])});
    }
  }

  void _openPhoto(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PhotoDetailScreen(
          photoId: photoId,
          data: data,
          user: user,
          db: db,
        ),
      ),
    );
  }
}

// ── Photo Detail ──────────────────────────────────────────────────
class _PhotoDetailScreen extends StatelessWidget {
  final String photoId;
  final Map<String, dynamic> data;
  final UserModel user;
  final FirebaseFirestore db;
  const _PhotoDetailScreen({
    required this.photoId,
    required this.data,
    required this.user,
    required this.db,
  });

  @override
  Widget build(BuildContext context) {
    final url = data['url'] as String? ?? '';
    final uploaderName = data['uploaderName'] as String? ?? '';
    final likedBy = List<String>.from(data['likedBy'] as List? ?? []);
    final isLiked = likedBy.contains(user.uid);
    final commentCount = data['commentCount'] as int? ?? 0;
    final createdAt = data['createdAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(
            (data['createdAt'] as dynamic).millisecondsSinceEpoch)
        : DateTime.now();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(uploaderName,
            style: const TextStyle(color: Colors.white, fontSize: 15)),
        actions: [
          if (user.isAdmin || data['uploadedBy'] == user.uid)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              onPressed: () {
                db.collection('photos').doc(photoId).delete();
                Navigator.pop(context);
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        final ref = db.collection('photos').doc(photoId);
                        if (isLiked) {
                          ref.update({'likedBy': FieldValue.arrayRemove([user.uid])});
                        } else {
                          ref.update({'likedBy': FieldValue.arrayUnion([user.uid])});
                        }
                      },
                      child: Row(
                        children: [
                          Icon(isLiked ? Icons.favorite : Icons.favorite_border,
                              size: 22,
                              color: isLiked ? Colors.red : AppTheme.textSecondary),
                          const SizedBox(width: 6),
                          Text('${likedBy.length}',
                              style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    GestureDetector(
                      onTap: () => _openComments(context),
                      child: Row(
                        children: [
                          const Icon(Icons.chat_bubble_outline,
                              size: 20, color: AppTheme.textSecondary),
                          const SizedBox(width: 6),
                          Text('$commentCount',
                              style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(DateFormat('MMM d, y').format(createdAt),
                        style: const TextStyle(
                            color: AppTheme.textHint, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openComments(BuildContext context) {
    // Reuse the same comments pattern
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PhotoCommentsSheet(
          photoId: photoId, user: user, db: db),
    );
  }
}

class _PhotoCommentsSheet extends StatefulWidget {
  final String photoId;
  final UserModel user;
  final FirebaseFirestore db;
  const _PhotoCommentsSheet(
      {required this.photoId, required this.user, required this.db});

  @override
  State<_PhotoCommentsSheet> createState() => _PhotoCommentsSheetState();
}

class _PhotoCommentsSheetState extends State<_PhotoCommentsSheet> {
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
      builder: (_, sc) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36, height: 4,
              decoration: BoxDecoration(color: AppTheme.cardBorder,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const Text('Comments',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const Divider(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: widget.db
                    .collection('photos')
                    .doc(widget.photoId)
                    .collection('comments')
                    .orderBy('createdAt')
                    .snapshots(),
                builder: (_, snap) {
                  final docs = snap.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(
                        child: Text('No comments yet',
                            style: TextStyle(color: AppTheme.textHint)));
                  }
                  return ListView.builder(
                    controller: sc,
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    itemBuilder: (_, i) {
                      final d = docs[i].data() as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor:
                                  AppTheme.navy.withValues(alpha: 0.1),
                              child: Text(
                                  (d['authorName'] as String? ?? '?')[0]
                                      .toUpperCase(),
                                  style: const TextStyle(
                                      color: AppTheme.navy, fontSize: 12)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(d['authorName'] as String? ?? '',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12)),
                                  Text(d['content'] as String? ?? '',
                                      style: const TextStyle(fontSize: 13)),
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
            const Divider(),
            Padding(
              padding: EdgeInsets.only(
                left: 16, right: 16, top: 8,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      decoration: const InputDecoration(
                          hintText: 'Comment…', border: OutlineInputBorder()),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: AppTheme.navy),
                    onPressed: _sending ? null : _send,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await widget.db
          .collection('photos')
          .doc(widget.photoId)
          .collection('comments')
          .add({
        'authorId': widget.user.uid,
        'authorName': widget.user.displayName,
        'content': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await widget.db.collection('photos').doc(widget.photoId).update({
        'commentCount': FieldValue.increment(1),
      });
      _ctrl.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}
