// lib/screens/photos/photos_screen.dart
// Photo albums: create albums, upload photos (web+mobile), folder icons,
// comments, reactions (like/heart/pray), title/description
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
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
  bool _uploading = false;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser!;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Photo Albums'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!user.isStudent)
            IconButton(
              icon: const Icon(Icons.create_new_folder_outlined),
              tooltip: 'New Album',
              onPressed: () => _showCreateAlbumDialog(context, user),
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('albums').orderBy('createdAt', descending: true).snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            // No index needed – use in-memory sort fallback
            return _buildAlbumGrid(context, user, []);
          }
          final docs = snap.data?.docs ?? [];
          return _buildAlbumGrid(context, user, docs);
        },
      ),
      floatingActionButton: !user.isStudent
          ? FloatingActionButton.extended(
              onPressed: _uploading
                  ? null
                  : () => _uploadToDefault(context, user),
              backgroundColor: AppTheme.photosColor,
              icon: _uploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.add_a_photo),
              label: const Text('Upload Photo'),
            )
          : null,
    );
  }

  Widget _buildAlbumGrid(BuildContext context, UserModel user,
      List<QueryDocumentSnapshot> docs) {
    // Sort in memory
    final sorted = [...docs];
    sorted.sort((a, b) {
      final aT = (a.data() as Map)['createdAt'];
      final bT = (b.data() as Map)['createdAt'];
      if (aT == null) return 1;
      if (bT == null) return -1;
      return (bT as dynamic).millisecondsSinceEpoch
          .compareTo((aT as dynamic).millisecondsSinceEpoch);
    });

    if (sorted.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.photo_library_outlined,
                size: 64, color: AppTheme.textHint),
            const SizedBox(height: 16),
            const Text('No albums yet',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            const Text('Create an album to organise memories',
                style: TextStyle(color: AppTheme.textHint)),
            const SizedBox(height: 20),
            if (!user.isStudent)
              ElevatedButton.icon(
                onPressed: () => _showCreateAlbumDialog(context, user),
                icon: const Icon(Icons.create_new_folder_outlined),
                label: const Text('Create Album'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.photosColor),
              ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: sorted.length,
      itemBuilder: (_, i) {
        final data = sorted[i].data() as Map<String, dynamic>;
        return _AlbumFolderTile(
          albumId: sorted[i].id,
          data: data,
          user: user,
          db: _db,
          storage: _storage,
        );
      },
    );
  }

  // ── Create Album Dialog ─────────────────────────────────────────
  void _showCreateAlbumDialog(BuildContext context, UserModel user) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setS) => AlertDialog(
          title: const Text('New Album'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Album Title *',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder()),
                maxLines: 2,
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
                      await _db.collection('albums').add({
                        'name': nameCtrl.text.trim(),
                        'description': descCtrl.text.trim(),
                        'createdBy': user.uid,
                        'creatorName': user.displayName,
                        'photoCount': 0,
                        'coverUrl': null,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Upload to General (default) album ───────────────────────────
  Future<void> _uploadToDefault(BuildContext context, UserModel user) async {
    // Pick file using file_picker (works on web + mobile)
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    setState(() => _uploading = true);

    try {
      // Ensure "General" album exists
      String albumId;
      final existing = await _db
          .collection('albums')
          .where('name', isEqualTo: 'General')
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        albumId = existing.docs.first.id;
      } else {
        final newAlbum = await _db.collection('albums').add({
          'name': 'General',
          'description': 'Unsorted photos',
          'createdBy': user.uid,
          'creatorName': user.displayName,
          'photoCount': 0,
          'coverUrl': null,
          'createdAt': FieldValue.serverTimestamp(),
        });
        albumId = newAlbum.id;
      }
      await _uploadBytes(context, user, albumId, bytes, file.name ?? 'photo.jpg');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _uploadBytes(BuildContext context, UserModel user,
      String albumId, Uint8List bytes, String fileName) async {
    final ext = fileName.contains('.') ? fileName.split('.').last : 'jpg';
    final storageName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final ref = _storage.ref().child('albums/$albumId/$storageName');
    final task = await ref.putData(bytes, SettableMetadata(contentType: 'image/$ext'));
    final url = await task.ref.getDownloadURL();

    await _db.collection('photos').add({
      'albumId': albumId,
      'url': url,
      'uploadedBy': user.uid,
      'uploaderName': user.displayName,
      'reactions': {},
      'commentCount': 0,
      'caption': '',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Update album photo count and cover
    await _db.collection('albums').doc(albumId).update({
      'photoCount': FieldValue.increment(1),
      'coverUrl': url,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Photo uploaded!'),
            backgroundColor: AppTheme.success),
      );
    }
  }
}

// ── Album Folder Tile ──────────────────────────────────────────────
class _AlbumFolderTile extends StatelessWidget {
  final String albumId;
  final Map<String, dynamic> data;
  final UserModel user;
  final FirebaseFirestore db;
  final FirebaseStorage storage;
  const _AlbumFolderTile({
    required this.albumId,
    required this.data,
    required this.user,
    required this.db,
    required this.storage,
  });

  @override
  Widget build(BuildContext context) {
    final name = data['name'] as String? ?? 'Album';
    final desc = data['description'] as String? ?? '';
    final coverUrl = data['coverUrl'] as String?;
    final photoCount = data['photoCount'] as int? ?? 0;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _AlbumDetailScreen(
            albumId: albumId,
            albumName: name,
            user: user,
            db: db,
            storage: storage,
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.cardBorder),
          boxShadow: [
            BoxShadow(
                color: AppTheme.photosColor.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Folder image / thumbnail
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14)),
                child: coverUrl != null && coverUrl.isNotEmpty
                    ? Image.network(
                        coverUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) =>
                            _folderPlaceholder(),
                      )
                    : _folderPlaceholder(),
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (desc.isNotEmpty)
                    Text(desc,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textHint),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.photo_outlined,
                          size: 12,
                          color: AppTheme.textHint),
                      const SizedBox(width: 3),
                      Text('$photoCount photo${photoCount != 1 ? 's' : ''}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textHint)),
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

  Widget _folderPlaceholder() {
    return Container(
      color: AppTheme.photosColor.withValues(alpha: 0.08),
      child: const Center(
        child: Icon(Icons.photo_album_outlined,
            size: 48, color: AppTheme.photosColor),
      ),
    );
  }
}

// ── Album Detail Screen ────────────────────────────────────────────
class _AlbumDetailScreen extends StatefulWidget {
  final String albumId;
  final String albumName;
  final UserModel user;
  final FirebaseFirestore db;
  final FirebaseStorage storage;
  const _AlbumDetailScreen({
    required this.albumId,
    required this.albumName,
    required this.user,
    required this.db,
    required this.storage,
  });

  @override
  State<_AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<_AlbumDetailScreen> {
  bool _uploading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(widget.albumName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: widget.db
            .collection('photos')
            .where('albumId', isEqualTo: widget.albumId)
            .snapshots(),
        builder: (ctx, snap) {
          final docs = snap.data?.docs ?? [];
          // Sort in memory
          final sorted = [...docs];
          sorted.sort((a, b) {
            final aT = (a.data() as Map)['createdAt'];
            final bT = (b.data() as Map)['createdAt'];
            if (aT == null) return 1;
            if (bT == null) return -1;
            return (bT as dynamic).millisecondsSinceEpoch
                .compareTo((aT as dynamic).millisecondsSinceEpoch);
          });

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_photo_alternate_outlined,
                      size: 64, color: AppTheme.textHint),
                  const SizedBox(height: 12),
                  const Text('No photos yet',
                      style: TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 16),
                  if (!widget.user.isStudent)
                    ElevatedButton.icon(
                      onPressed: _uploading
                          ? null
                          : () => _uploadPhoto(context),
                      icon: const Icon(Icons.add_a_photo),
                      label: const Text('Add Photo'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.photosColor),
                    ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: sorted.length,
            itemBuilder: (_, i) {
              final d = sorted[i].data() as Map<String, dynamic>;
              return _PhotoTile(
                photoId: sorted[i].id,
                data: d,
                user: widget.user,
                db: widget.db,
              );
            },
          );
        },
      ),
      floatingActionButton: !widget.user.isStudent
          ? FloatingActionButton(
              onPressed: _uploading ? null : () => _uploadPhoto(context),
              backgroundColor: AppTheme.photosColor,
              child: _uploading
                  ? const CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2)
                  : const Icon(Icons.add_a_photo),
            )
          : null,
    );
  }

  Future<void> _uploadPhoto(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    setState(() => _uploading = true);
    try {
      final ext = (file.extension ?? 'jpg').toLowerCase();
      final storageName =
          '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final ref = widget.storage
          .ref()
          .child('albums/${widget.albumId}/$storageName');
      final task = await ref.putData(
          bytes, SettableMetadata(contentType: 'image/$ext'));
      final url = await task.ref.getDownloadURL();

      await widget.db.collection('photos').add({
        'albumId': widget.albumId,
        'url': url,
        'uploadedBy': widget.user.uid,
        'uploaderName': widget.user.displayName,
        'reactions': {},
        'commentCount': 0,
        'caption': '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await widget.db
          .collection('albums')
          .doc(widget.albumId)
          .update({
        'photoCount': FieldValue.increment(1),
        'coverUrl': url,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Photo uploaded!'),
              backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Upload failed: $e'),
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
    final reactions = Map<String, dynamic>.from(
        data['reactions'] as Map? ?? {});
    final heartCount =
        (reactions['heart'] as List? ?? []).length;
    final isHearted =
        (reactions['heart'] as List? ?? []).contains(user.uid);

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
                    child: const Center(
                        child: CircularProgressIndicator(
                            strokeWidth: 1)),
                  ),
            errorBuilder: (_, __, ___) => Container(
              color: AppTheme.surfaceVariant,
              child: const Icon(Icons.broken_image,
                  color: AppTheme.textHint),
            ),
          ),
          Positioned(
            bottom: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _toggleReaction('heart', isHearted),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isHearted
                          ? Icons.favorite
                          : Icons.favorite_border,
                      size: 12,
                      color:
                          isHearted ? Colors.red : Colors.white,
                    ),
                    const SizedBox(width: 3),
                    Text('$heartCount',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleReaction(String type, bool hasIt) {
    final ref = db.collection('photos').doc(photoId);
    if (hasIt) {
      ref.update({
        'reactions.$type': FieldValue.arrayRemove([user.uid]),
      });
    } else {
      ref.update({
        'reactions.$type': FieldValue.arrayUnion([user.uid]),
      });
    }
  }

  void _openPhoto(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PhotoDetailScreen(
            photoId: photoId, data: data, user: user, db: db),
      ),
    );
  }
}

// ── Photo Detail Screen ───────────────────────────────────────────
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
    final caption = data['caption'] as String? ?? '';
    final reactions = Map<String, dynamic>.from(
        data['reactions'] as Map? ?? {});
    final heartList = List<String>.from(
        reactions['heart'] as List? ?? []);
    final prayList = List<String>.from(
        reactions['pray'] as List? ?? []);
    final thumbList = List<String>.from(
        reactions['thumb'] as List? ?? []);
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
                if (caption.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(caption,
                        style: const TextStyle(fontSize: 14)),
                  ),
                // Reaction row
                Row(
                  children: [
                    _ReactionBtn(
                      emoji: '❤️',
                      count: heartList.length,
                      active: heartList.contains(user.uid),
                      onTap: () => _toggleReaction(
                          context, 'heart', heartList.contains(user.uid)),
                    ),
                    const SizedBox(width: 12),
                    _ReactionBtn(
                      emoji: '👍',
                      count: thumbList.length,
                      active: thumbList.contains(user.uid),
                      onTap: () => _toggleReaction(
                          context, 'thumb', thumbList.contains(user.uid)),
                    ),
                    const SizedBox(width: 12),
                    _ReactionBtn(
                      emoji: '🙏',
                      count: prayList.length,
                      active: prayList.contains(user.uid),
                      onTap: () => _toggleReaction(
                          context, 'pray', prayList.contains(user.uid)),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _openComments(context),
                      child: Row(
                        children: [
                          const Icon(Icons.chat_bubble_outline,
                              size: 18,
                              color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text('$commentCount',
                              style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(DateFormat('MMM d, y').format(createdAt),
                        style: const TextStyle(
                            color: AppTheme.textHint, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toggleReaction(BuildContext context, String type, bool hasIt) {
    final ref = db.collection('photos').doc(photoId);
    if (hasIt) {
      ref.update({
        'reactions.$type': FieldValue.arrayRemove([user.uid]),
      });
    } else {
      ref.update({
        'reactions.$type': FieldValue.arrayUnion([user.uid]),
      });
    }
  }

  void _openComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PhotoCommentsSheet(
          photoId: photoId, user: user, db: db),
    );
  }
}

class _ReactionBtn extends StatelessWidget {
  final String emoji;
  final int count;
  final bool active;
  final VoidCallback onTap;
  const _ReactionBtn({
    required this.emoji,
    required this.count,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? AppTheme.navy.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active
                  ? AppTheme.navy.withValues(alpha: 0.4)
                  : AppTheme.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text('$count',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Photo Comments Sheet ──────────────────────────────────────────
class _PhotoCommentsSheet extends StatefulWidget {
  final String photoId;
  final UserModel user;
  final FirebaseFirestore db;
  const _PhotoCommentsSheet(
      {required this.photoId, required this.user, required this.db});

  @override
  State<_PhotoCommentsSheet> createState() =>
      _PhotoCommentsSheetState();
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
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: AppTheme.cardBorder,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const Text('Comments',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
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
                            style:
                                TextStyle(color: AppTheme.textHint)));
                  }
                  return ListView.builder(
                    controller: sc,
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    itemBuilder: (_, i) {
                      final d =
                          docs[i].data() as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: AppTheme.navy
                                  .withValues(alpha: 0.1),
                              child: Text(
                                  (d['authorName'] as String? ??
                                          '?')[0]
                                      .toUpperCase(),
                                  style: const TextStyle(
                                      color: AppTheme.navy,
                                      fontSize: 12)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      d['authorName'] as String? ??
                                          '',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12)),
                                  Text(
                                      d['content'] as String? ?? '',
                                      style: const TextStyle(
                                          fontSize: 13)),
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
                left: 16,
                right: 16,
                top: 8,
                bottom:
                    MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      decoration: const InputDecoration(
                          hintText: 'Comment…',
                          border: OutlineInputBorder()),
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
      await widget.db
          .collection('photos')
          .doc(widget.photoId)
          .update({
        'commentCount': FieldValue.increment(1),
      });
      _ctrl.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}
