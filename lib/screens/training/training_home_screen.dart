// lib/screens/training/training_home_screen.dart
// P2-2: Training home — category grid with badge counts.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';
import '../../models/training_models.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_animations.dart';
import 'training_category_screen.dart';
import 'admin_training_screen.dart';

class TrainingHomeScreen extends StatefulWidget {
  final UserModel user;
  const TrainingHomeScreen({super.key, required this.user});

  @override
  State<TrainingHomeScreen> createState() => _TrainingHomeScreenState();
}

class _TrainingHomeScreenState extends State<TrainingHomeScreen> {
  Set<String> _viewed = {};

  @override
  void initState() {
    super.initState();
    _loadViewed();
  }

  Future<void> _loadViewed() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('training_viewed_${widget.user.uid}') ?? [];
    if (mounted) setState(() => _viewed = list.toSet());
  }

  List<String> _categoriesForUser() {
    if (widget.user.isAdmin) {
      return TrainingCategory.labels.keys.toList();
    }
    if (widget.user.canMentor) {
      return [
        TrainingCategory.mentorOrientation,
        TrainingCategory.classicalEducation,
        TrainingCategory.coopPolicies,
      ];
    }
    return [
      TrainingCategory.parentResources,
      TrainingCategory.classicalEducation,
      TrainingCategory.coopPolicies,
    ];
  }

  static const _categoryIcons = <String, IconData>{
    TrainingCategory.mentorOrientation:  Icons.school_outlined,
    TrainingCategory.parentResources:    Icons.family_restroom_outlined,
    TrainingCategory.classicalEducation: Icons.menu_book_outlined,
    TrainingCategory.coopPolicies:       Icons.policy_outlined,
  };

  static const _categoryColors = <String, Color>{
    TrainingCategory.mentorOrientation:  Color(0xFF1565C0),
    TrainingCategory.parentResources:    Color(0xFF2E7D32),
    TrainingCategory.classicalEducation: Color(0xFF6A1B9A),
    TrainingCategory.coopPolicies:       Color(0xFF4E342E),
  };

  @override
  Widget build(BuildContext context) {
    final categories = _categoriesForUser();
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.navyDark,
        foregroundColor: Colors.white,
        title: const Text('Training Resources',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
        actions: [
          if (widget.user.isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_outlined,
                  color: AppTheme.gold),
              tooltip: 'Manage Resources',
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          AdminTrainingScreen(user: widget.user))),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.1,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final cat = categories[index];
            return _CategoryCard(
              category: cat,
              label: TrainingCategory.labels[cat] ?? cat,
              icon: _categoryIcons[cat] ?? Icons.folder_outlined,
              color: _categoryColors[cat] ?? AppTheme.classesColor,
              user: widget.user,
              viewed: _viewed,
            )
                .animate(delay: Duration(milliseconds: 80 * index))
                .fadeIn(duration: AppAnimations.cardFadeInDuration)
                .scale(
                    begin: const Offset(0.92, 0.92),
                    end: const Offset(1, 1),
                    curve: Curves.easeOut);
          },
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String category;
  final String label;
  final IconData icon;
  final Color color;
  final UserModel user;
  final Set<String> viewed;

  const _CategoryCard({
    required this.category,
    required this.label,
    required this.icon,
    required this.color,
    required this.user,
    required this.viewed,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('training_resources')
          .where('category', isEqualTo: category)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        final unread = docs.where((d) => !viewed.contains(d.id)).length;

        return InkWell(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => TrainingCategoryScreen(
                        category: category,
                        label: label,
                        color: color,
                        user: user,
                      ))),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.85),
                  color,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ],
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: Colors.white, size: 36),
                      const SizedBox(height: 10),
                      Text(label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      const SizedBox(height: 4),
                      Text('${docs.length} item${docs.length == 1 ? '' : 's'}',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 12)),
                    ],
                  ),
                ),
                if (unread > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                          unread > 9 ? '9+' : '$unread',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
