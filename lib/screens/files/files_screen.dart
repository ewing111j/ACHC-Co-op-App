// lib/screens/files/files_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../utils/app_theme.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  final _firestoreService = FirestoreService();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser!;
    final familyId = user.familyId ?? '';

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
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search files...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _firestoreService.streamFiles(familyId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var files = snapshot.data ?? [];
                if (_searchQuery.isNotEmpty) {
                  files = files
                      .where((f) =>
                          (f['name'] as String? ?? '')
                              .toLowerCase()
                              .contains(_searchQuery.toLowerCase()))
                      .toList();
                }

                if (files.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.folder_open,
                            size: 64, color: AppTheme.textHint),
                        const SizedBox(height: 16),
                        const Text(
                          'No files yet',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        const Text('Share documents with your co-op',
                            style: TextStyle(color: AppTheme.textHint)),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => _showAddFileDialog(
                              context, user, familyId),
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Add File Link'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.filesColor),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: files.length,
                  itemBuilder: (ctx, i) =>
                      _buildFileCard(ctx, files[i]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            _showAddFileDialog(context, user, user.familyId ?? ''),
        backgroundColor: AppTheme.filesColor,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFileCard(BuildContext context, Map<String, dynamic> file) {
    final name = file['name'] as String? ?? 'Unknown File';
    final url = file['url'] as String? ?? '';
    final type = file['type'] as String? ?? 'file';
    final uploadedBy = file['uploadedBy'] as String? ?? '';
    final uploadedAt = file['uploadedAt'];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _getFileColor(type).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_getFileIcon(type),
              color: _getFileColor(type), size: 24),
        ),
        title: Text(
          name,
          style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (uploadedBy.isNotEmpty)
              Text('By $uploadedBy',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary)),
            if (uploadedAt != null)
              Text(
                DateFormat('MMM d, y').format(DateTime.fromMillisecondsSinceEpoch(
                    (uploadedAt as dynamic).millisecondsSinceEpoch as int)),
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textHint),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.open_in_new, size: 20),
          onPressed: () async {
            if (url.isNotEmpty) {
              final uri = Uri.tryParse(url);
              if (uri != null && await canLaunchUrl(uri)) {
                await launchUrl(uri,
                    mode: LaunchMode.externalApplication);
              }
            }
          },
        ),
        onTap: () async {
          if (url.isNotEmpty) {
            final uri = Uri.tryParse(url);
            if (uri != null && await canLaunchUrl(uri)) {
              await launchUrl(uri,
                  mode: LaunchMode.externalApplication);
            }
          }
        },
      ),
    );
  }

  IconData _getFileIcon(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'image':
      case 'jpg':
      case 'png':
        return Icons.image;
      case 'video':
        return Icons.video_file;
      case 'link':
        return Icons.link;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return AppTheme.error;
      case 'doc':
      case 'docx':
        return AppTheme.info;
      case 'xls':
      case 'xlsx':
        return AppTheme.success;
      case 'ppt':
      case 'pptx':
        return AppTheme.warning;
      case 'link':
        return AppTheme.primary;
      default:
        return AppTheme.filesColor;
    }
  }

  void _showAddFileDialog(
      BuildContext context, user, String familyId) {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    String selectedType = 'link';

    final types = ['link', 'pdf', 'doc', 'xls', 'ppt', 'image', 'other'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add File / Link'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration:
                      const InputDecoration(labelText: 'File Name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'URL / Link',
                    hintText: 'https://...',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: types
                      .map((t) => DropdownMenuItem(
                          value: t, child: Text(t.toUpperCase())))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => selectedType = v ?? 'link'),
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
                if (nameCtrl.text.isEmpty || urlCtrl.text.isEmpty) return;
                await _firestoreService.saveFile({
                  'name': nameCtrl.text.trim(),
                  'url': urlCtrl.text.trim(),
                  'type': selectedType,
                  'uploadedBy': user.displayName,
                  'uploaderUid': user.uid,
                  'familyId': familyId,
                });
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.filesColor),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}
