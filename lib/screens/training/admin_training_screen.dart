// lib/screens/training/admin_training_screen.dart
// P2-2: Admin resource management — add/edit/delete training resources.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../models/user_model.dart';
import '../../models/training_models.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_animations.dart';

class AdminTrainingScreen extends StatelessWidget {
  final UserModel user;
  const AdminTrainingScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.navyDark,
        foregroundColor: Colors.white,
        title: const Text('Manage Training Resources',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.gold,
        foregroundColor: AppTheme.navyDark,
        icon: const Icon(Icons.add),
        label: const Text('Add Resource'),
        onPressed: () => _showAddSheet(context),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('training_resources')
            .orderBy('order')
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
                child: Text('No resources yet. Tap + to add.',
                    style: TextStyle(color: AppTheme.textHint)));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final r = TrainingResourceModel.fromFirestore(
                  doc.data() as Map<String, dynamic>, doc.id);
              return _AdminResourceTile(resource: r)
                  .animate(delay: Duration(milliseconds: 40 * index))
                  .fadeIn(duration: AppAnimations.cardFadeInDuration);
            },
          );
        },
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddResourceSheet(),
    );
  }
}

class _AdminResourceTile extends StatelessWidget {
  final TrainingResourceModel resource;
  const _AdminResourceTile({required this.resource});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(
          resource.isVideo ? Icons.play_circle_outline : Icons.picture_as_pdf,
          color: AppTheme.classesColor,
        ),
        title: Text(resource.title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
            '${TrainingCategory.labels[resource.category] ?? resource.category} · ${resource.type.toUpperCase()}',
            style: const TextStyle(fontSize: 12)),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => _confirmDelete(context),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Resource'),
        content: Text('Delete "${resource.title}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('training_resources')
                  .doc(resource.id)
                  .delete();
              Navigator.pop(context);
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _AddResourceSheet extends StatefulWidget {
  const _AddResourceSheet();
  @override
  State<_AddResourceSheet> createState() => _AddResourceSheetState();
}

class _AddResourceSheetState extends State<_AddResourceSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _category = TrainingCategory.mentorOrientation;
  String _type = 'pdf';
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _urlCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final id = const Uuid().v4();
      await FirebaseFirestore.instance
          .collection('training_resources')
          .doc(id)
          .set({
        'title': _titleCtrl.text.trim(),
        'category': _category,
        'type': _type,
        'url': _urlCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'roles': ['parent', 'mentor', 'admin'],
        'publishedAt': FieldValue.serverTimestamp(),
        'order': 99,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 60),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
              const Text('Add Training Resource',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.navyDark)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: TrainingCategory.labels.entries
                    .map((e) => DropdownMenuItem(
                        value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 12),
              Row(children: [
                const Text('Type:',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(width: 12),
                ChoiceChip(
                    label: const Text('PDF'),
                    selected: _type == 'pdf',
                    onSelected: (_) => setState(() => _type = 'pdf')),
                const SizedBox(width: 8),
                ChoiceChip(
                    label: const Text('Video'),
                    selected: _type == 'video',
                    onSelected: (_) => setState(() => _type = 'video')),
              ]),
              const SizedBox(height: 12),
              TextFormField(
                controller: _urlCtrl,
                decoration: InputDecoration(
                    labelText: _type == 'video'
                        ? 'YouTube / Video URL'
                        : 'PDF URL or Storage Path'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Description',
                    alignLabelWithHint: true),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.navyDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Save Resource',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
