// lib/screens/training/training_category_screen.dart
// P2-2: List of resources in a category.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../models/training_models.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_animations.dart';
import 'training_resource_screen.dart';

class TrainingCategoryScreen extends StatelessWidget {
  final String category;
  final String label;
  final Color color;
  final UserModel user;

  const TrainingCategoryScreen({
    super.key,
    required this.category,
    required this.label,
    required this.color,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: color,
        foregroundColor: Colors.white,
        title: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('training_resources')
            .where('category', isEqualTo: category)
            .orderBy('order')
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open,
                      size: 64,
                      color: color.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  const Text('No resources yet',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.navyDark)),
                ],
              ),
            );
          }
          final resources = docs
              .map((d) => TrainingResourceModel.fromFirestore(
                  d.data() as Map<String, dynamic>, d.id))
              .toList();
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: resources.length,
            itemBuilder: (context, index) {
              final r = resources[index];
              return _ResourceTile(
                resource: r,
                color: color,
                user: user,
              )
                  .animate(delay: Duration(milliseconds: 60 * index))
                  .fadeIn(duration: AppAnimations.cardFadeInDuration)
                  .moveX(begin: -12, end: 0);
            },
          );
        },
      ),
    );
  }
}

class _ResourceTile extends StatelessWidget {
  final TrainingResourceModel resource;
  final Color color;
  final UserModel user;

  const _ResourceTile({
    required this.resource,
    required this.color,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            resource.isVideo ? Icons.play_circle_outline : Icons.picture_as_pdf,
            color: color,
            size: 26,
          ),
        ),
        title: Text(resource.title,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(resource.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    resource.isVideo ? 'VIDEO' : 'PDF',
                    style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                if (resource.isVideo && resource.durationLabel.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(resource.durationLabel,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textHint)),
                ],
                if (resource.isPdf && resource.pageCount != null) ...[
                  const SizedBox(width: 6),
                  Text('${resource.pageCount} pages',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textHint)),
                ],
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.textHint),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => TrainingResourceScreen(
                    resource: resource,
                    color: color,
                    user: user,
                  )),
        ),
      ),
    );
  }
}
