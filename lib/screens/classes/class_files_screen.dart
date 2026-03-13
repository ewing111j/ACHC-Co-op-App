// lib/screens/classes/class_files_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import '../../models/user_model.dart';
import '../../models/class_models.dart';
import '../../utils/app_theme.dart';

class ClassFilesScreen extends StatefulWidget {
  final ClassModel classModel;
  final UserModel user;
  const ClassFilesScreen({super.key, required this.classModel, required this.user});

  @override
  State<ClassFilesScreen> createState() => _ClassFilesScreenState();
}

class _ClassFilesScreenState extends State<ClassFilesScreen> {
  final _db = FirebaseFirestore.instance;
  bool _uploading = false;

  @override
  Widget build(BuildContext context) {
    final cls = widget.classModel;
    final user = widget.user;
    final canUpload = user.canMentor || user.isAdmin;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Files · ${cls.shortname}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: canUpload
          ? FloatingActionButton.extended(
              onPressed: _uploading ? null : () => _pickAndUpload(context),
              icon: _uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.upload_file),
              label: Text(_uploading ? 'Uploading…' : 'Upload File'),
              backgroundColor: Color(cls.colorValue),
            )
          : null,
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('classes')
            .doc(cls.id)
            .collection('files')
            .orderBy('uploadedAt', descending: true)
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final files = snap.data!.docs
              .map((d) => ClassFileModel.fromMap(
                  d.data() as Map<String, dynamic>, d.id))
              .toList();

          // Sort: pinned first
          files.sort((a, b) {
            if (a.isPinned && !b.isPinned) return -1;
            if (!a.isPinned && b.isPinned) return 1;
            return b.uploadedAt.compareTo(a.uploadedAt);
          });

          if (files.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open_outlined,
                      size: 56, color: AppTheme.textTertiary),
                  SizedBox(height: 16),
                  Text('No files uploaded yet.',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 15)),
                ],
              ),
            );
          }

          // Group: pinned vs regular
          final pinned = files.where((f) => f.isPinned).toList();
          final regular = files.where((f) => !f.isPinned).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            children: [
              if (pinned.isNotEmpty) ...[
                _SectionHeader(title: 'Pinned Resources', icon: Icons.push_pin),
                const SizedBox(height: 8),
                ...pinned.map((f) => _FileTile(
                    file: f,
                    user: user,
                    db: _db,
                    cls: cls)),
                const SizedBox(height: 16),
              ],
              if (regular.isNotEmpty) ...[
                _SectionHeader(
                    title: 'All Files',
                    icon: Icons.folder_outlined),
                const SizedBox(height: 8),
                ...regular.map((f) => _FileTile(
                    file: f,
                    user: user,
                    db: _db,
                    cls: cls)),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickAndUpload(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(withData: kIsWeb);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    setState(() => _uploading = true);
    try {
      final path =
          'class_files/${widget.classModel.id}/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final ref = FirebaseStorage.instance.ref(path);
      if (kIsWeb && file.bytes != null) {
        await ref.putData(file.bytes!);
      }
      final url = await ref.getDownloadURL();
      final ext = file.name.split('.').last.toLowerCase();
      final fileType = _detectFileType(ext);
      await _db
          .collection('classes')
          .doc(widget.classModel.id)
          .collection('files')
          .add({
        'classId': widget.classModel.id,
        'name': file.name,
        'url': url,
        'fileType': fileType,
        'isPinned': false,
        'uploaderUid': widget.user.uid,
        'uploaderName': widget.user.displayName,
        'uploadedAt': FieldValue.serverTimestamp(),
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('File uploaded!'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _detectFileType(String ext) {
    switch (ext) {
      case 'pdf':
        return 'pdf';
      case 'mp4':
      case 'mov':
      case 'avi':
        return 'video';
      case 'doc':
      case 'docx':
        return 'doc';
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return 'image';
      default:
        return 'other';
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 6),
        Text(title,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
                letterSpacing: 0.5)),
      ],
    );
  }
}

class _FileTile extends StatelessWidget {
  final ClassFileModel file;
  final UserModel user;
  final FirebaseFirestore db;
  final ClassModel cls;
  const _FileTile(
      {required this.file,
      required this.user,
      required this.db,
      required this.cls});

  @override
  Widget build(BuildContext context) {
    final canManage = user.canMentor || user.isAdmin;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        dense: true,
        leading: _FileIcon(type: file.fileType, color: Color(cls.colorValue)),
        title: Text(file.name,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500)),
        subtitle: Text(
          '${file.uploaderName} · ${DateFormat('MMM d').format(file.uploadedAt)}',
          style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (file.isPinned)
              const Icon(Icons.push_pin, size: 14, color: Colors.orange),
            if (canManage)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18),
                itemBuilder: (_) => [
                  PopupMenuItem(
                      value: 'pin',
                      child: Text(
                          file.isPinned ? 'Unpin' : 'Pin to Top')),
                  const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete',
                          style: TextStyle(color: Colors.red))),
                ],
                onSelected: (val) {
                  if (val == 'pin') _togglePin(context);
                  if (val == 'delete') _delete(context);
                },
              ),
          ],
        ),
        onTap: () => _open(context),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final uri = Uri.parse(file.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot open file')));
      }
    }
  }

  Future<void> _togglePin(BuildContext context) async {
    try {
      await db
          .collection('classes')
          .doc(cls.id)
          .collection('files')
          .doc(file.id)
          .update({'isPinned': !file.isPinned});
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
      }
    }
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete File?'),
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
          .collection('files')
          .doc(file.id)
          .delete();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
      }
    }
  }
}

class _FileIcon extends StatelessWidget {
  final String type;
  final Color color;
  const _FileIcon({required this.type, required this.color});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color iconColor;
    switch (type) {
      case 'pdf':
        icon = Icons.picture_as_pdf;
        iconColor = Colors.red;
        break;
      case 'video':
        icon = Icons.play_circle_outline;
        iconColor = Colors.purple;
        break;
      case 'doc':
        icon = Icons.description_outlined;
        iconColor = Colors.blue;
        break;
      case 'image':
        icon = Icons.image_outlined;
        iconColor = Colors.teal;
        break;
      case 'url':
        icon = Icons.link;
        iconColor = Colors.orange;
        break;
      default:
        icon = Icons.insert_drive_file_outlined;
        iconColor = color;
    }
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: 18, color: iconColor),
    );
  }
}
