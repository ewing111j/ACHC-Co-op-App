// lib/screens/files/files_screen.dart
// Upload/host documents, pin to top, admin control
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../utils/app_theme.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  bool _uploading = false;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser!;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Files'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search files…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('files')
                  .orderBy('isPinned', descending: true)
                  .orderBy('uploadedAt', descending: true)
                  .snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var docs = snap.data?.docs ?? [];
                if (_searchQuery.isNotEmpty) {
                  docs = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    final name = (data['name'] as String? ?? '').toLowerCase();
                    return name.contains(_searchQuery);
                  }).toList();
                }

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.folder_outlined,
                            size: 64, color: AppTheme.textHint),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No files matching "$_searchQuery"'
                              : 'No files yet',
                          style: const TextStyle(
                              fontSize: 16, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                // Separate pinned
                final pinned = docs
                    .where((d) =>
                        (d.data() as Map<String, dynamic>)['isPinned'] == true)
                    .toList();
                final regular = docs
                    .where((d) =>
                        (d.data() as Map<String, dynamic>)['isPinned'] != true)
                    .toList();

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    if (pinned.isNotEmpty) ...[
                      AppTheme.sectionHeader('Pinned'),
                      ...pinned.map((d) => _FileCard(
                            docId: d.id,
                            data: d.data() as Map<String, dynamic>,
                            user: user,
                            db: _db,
                          )),
                      const SizedBox(height: 8),
                    ],
                    if (regular.isNotEmpty) ...[
                      AppTheme.sectionHeader('All Files'),
                      ...regular.map((d) => _FileCard(
                            docId: d.id,
                            data: d.data() as Map<String, dynamic>,
                            user: user,
                            db: _db,
                          )),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: (user.isAdmin || user.isParent)
          ? FloatingActionButton(
              onPressed: _uploading ? null : () => _uploadFile(context, user),
              backgroundColor: AppTheme.filesColor,
              child: _uploading
                  ? const CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2)
                  : const Icon(Icons.upload_file),
            )
          : null,
    );
  }

  Future<void> _uploadFile(BuildContext context, UserModel user) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.path == null) return;

    setState(() => _uploading = true);
    try {
      final f = File(file.path!);
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final ref = _storage.ref().child('files/$fileName');
      final task = await ref.putFile(f);
      final url = await task.ref.getDownloadURL();

      await _db.collection('files').add({
        'name': file.name,
        'url': url,
        'size': file.size,
        'type': file.extension ?? 'unknown',
        'uploadedBy': user.uid,
        'uploaderName': user.displayName,
        'isPinned': false,
        'uploadedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('File uploaded!'),
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

// ── File Card ─────────────────────────────────────────────────────
class _FileCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final UserModel user;
  final FirebaseFirestore db;
  const _FileCard({
    required this.docId,
    required this.data,
    required this.user,
    required this.db,
  });

  @override
  Widget build(BuildContext context) {
    final name = data['name'] as String? ?? 'Unknown';
    final type = data['type'] as String? ?? '';
    final size = data['size'] as int? ?? 0;
    final isPinned = data['isPinned'] as bool? ?? false;
    final uploaderName = data['uploaderName'] as String? ?? '';
    final uploadedAt = data['uploadedAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(
            (data['uploadedAt'] as Timestamp).millisecondsSinceEpoch)
        : DateTime.now();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isPinned
              ? AppTheme.gold.withValues(alpha: 0.4)
              : AppTheme.cardBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _fileColor(type).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_fileIcon(type), color: _fileColor(type), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isPinned)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(Icons.push_pin, size: 12, color: AppTheme.gold),
                      ),
                    Expanded(
                      child: Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$uploaderName · ${_formatSize(size)} · ${DateFormat('MMM d').format(uploadedAt)}',
                  style: const TextStyle(
                      color: AppTheme.textHint, fontSize: 11),
                ),
              ],
            ),
          ),
          if (user.isAdmin || data['uploadedBy'] == user.uid)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18, color: AppTheme.textHint),
              onSelected: (v) {
                if (v == 'pin') {
                  db.collection('files').doc(docId).update({'isPinned': !isPinned});
                } else if (v == 'delete') {
                  db.collection('files').doc(docId).delete();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'pin',
                  child: Text(isPinned ? 'Unpin' : 'Pin to Top'),
                ),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
        ],
      ),
    );
  }

  IconData _fileIcon(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'doc':
      case 'docx':
        return Icons.article_outlined;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_outlined;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_outlined;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  Color _fileColor(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'xls':
      case 'xlsx':
        return Colors.green;
      case 'ppt':
      case 'pptx':
        return Colors.orange;
      default:
        return AppTheme.filesColor;
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}
