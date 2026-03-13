// lib/screens/photos/photos_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../models/photo_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/app_theme.dart';

class PhotosScreen extends StatefulWidget {
  const PhotosScreen({super.key});

  @override
  State<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends State<PhotosScreen> {
  final _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser!;
    final familyId = user.familyId ?? '';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Photos'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.grid_view),
            onPressed: () {},
          ),
        ],
      ),
      body: StreamBuilder<List<PhotoModel>>(
        stream: _firestoreService.streamPhotos(familyId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final photos = snapshot.data ?? [];

          if (photos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.photo_library_outlined,
                      size: 64, color: AppTheme.textHint),
                  const SizedBox(height: 16),
                  const Text(
                    'No photos yet',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Share memories with your co-op family',
                    style: TextStyle(color: AppTheme.textHint),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () =>
                        _showUploadDialog(context, user, familyId),
                    icon: const Icon(Icons.add_photo_alternate),
                    label: const Text('Add Photo'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.photosColor),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: photos.length,
            itemBuilder: (ctx, i) => _buildPhotoTile(ctx, photos[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showUploadDialog(context, user, familyId),
        backgroundColor: AppTheme.photosColor,
        child: const Icon(Icons.add_a_photo),
      ),
    );
  }

  Widget _buildPhotoTile(BuildContext context, PhotoModel photo) {
    return GestureDetector(
      onTap: () => _showPhotoDetail(context, photo),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            photo.url,
            fit: BoxFit.cover,
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child;
              return Container(
                color: AppTheme.surfaceVariant,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },
            errorBuilder: (ctx, err, stack) => Container(
              color: AppTheme.surfaceVariant,
              child: const Icon(Icons.broken_image,
                  color: AppTheme.textHint),
            ),
          ),
        ],
      ),
    );
  }

  void _showPhotoDetail(BuildContext context, PhotoModel photo) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            InteractiveViewer(
              child: Image.network(photo.url, fit: BoxFit.contain),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close,
                    color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            if (photo.caption.isNotEmpty)
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.7),
                        Colors.transparent
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        photo.caption,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${photo.uploaderName} • ${DateFormat('MMM d, y').format(photo.uploadedAt)}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showUploadDialog(BuildContext context, user, String familyId) {
    final captionCtrl = TextEditingController();
    final urlCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Photo'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Photo URL',
                  prefixIcon: Icon(Icons.link),
                  hintText: 'https://...',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: captionCtrl,
                decoration:
                    const InputDecoration(labelText: 'Caption (optional)'),
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
              if (urlCtrl.text.isEmpty) return;
              final photo = PhotoModel(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                url: urlCtrl.text.trim(),
                caption: captionCtrl.text.trim(),
                uploadedBy: user.uid,
                uploaderName: user.displayName,
                familyId: familyId,
                uploadedAt: DateTime.now(),
              );
              await _firestoreService.savePhoto(photo);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.photosColor),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
