import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../models/memory/memory_models.dart';
import '../../providers/memory_provider.dart';
import '../../utils/app_theme.dart';
import 'content_card_screen.dart';

class BySubjectScreen extends StatelessWidget {
  final UserModel user;
  const BySubjectScreen({super.key, required this.user});

  static const Map<String, String> _icons = {
    'religion': '✝️', 'scripture': '📖', 'latin': '🏛️',
    'grammar': '✏️', 'history': '🏰', 'science': '🔬',
    'math': '➕', 'geography': '🌍', 'great_words_1': '💬',
    'great_words_2': '📝', 'timeline': '⏳',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        title: const Text('By Subject'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<MemoryProvider>(builder: (context, provider, _) {
        final subjects = provider.subjects;
        if (subjects.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1.0,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: subjects.length,
          itemBuilder: (context, i) {
            final s = subjects[i];
            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ContentCardScreen(
                    subjectId: s.id,
                    unitNumber: provider.currentUnit,
                    user: user,
                  ),
                ),
              ),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_icons[s.id] ?? '📚',
                          style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 6),
                      Text(
                        s.name,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
