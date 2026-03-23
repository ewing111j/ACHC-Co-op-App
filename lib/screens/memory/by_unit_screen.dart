import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../models/memory/memory_models.dart';
import '../../providers/memory_provider.dart';
import '../../utils/app_theme.dart';
import 'content_card_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ByUnitScreen — horizontal UnitStrip + subject grid per unit
// ─────────────────────────────────────────────────────────────────────────────

class ByUnitScreen extends StatefulWidget {
  final UserModel user;
  const ByUnitScreen({super.key, required this.user});

  @override
  State<ByUnitScreen> createState() => _ByUnitScreenState();
}

class _ByUnitScreenState extends State<ByUnitScreen> {
  int _selectedUnit = 1;

  @override
  void initState() {
    super.initState();
    final provider = context.read<MemoryProvider>();
    _selectedUnit = provider.currentUnit;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        title: Text('By Unit · Unit $_selectedUnit'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<MemoryProvider>(builder: (context, provider, _) {
        final units = provider.units;
        final subjects = provider.subjects;
        if (units.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        return Column(
          children: [
            // Unit strip
            SizedBox(
              height: 64,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: units.length,
                itemBuilder: (context, i) {
                  final u = units[i];
                  final selected = u.unitNumber == _selectedUnit;
                  Color bg;
                  if (u.isReview) {
                    bg = AppTheme.gold;
                  } else if (u.isBreak) {
                    bg = Colors.grey[300]!;
                  } else {
                    bg = AppTheme.navy;
                  }
                  return GestureDetector(
                    onTap: () => setState(() => _selectedUnit = u.unitNumber),
                    child: Container(
                      width: 44,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(8),
                        border: selected
                            ? Border.all(color: AppTheme.gold, width: 2)
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (u.isReview)
                            const Icon(Icons.refresh, size: 14, color: Colors.white)
                          else if (u.isBreak)
                            const Icon(Icons.bedtime_outlined,
                                size: 14, color: Colors.white),
                          Text(
                            '${u.unitNumber}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: u.isBreak ? Colors.black54 : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Subject grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.1,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: subjects.length,
                itemBuilder: (context, i) {
                  final s = subjects[i];
                  return _SubjectTile(
                    subject: s,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ContentCardScreen(
                          subjectId: s.id,
                          unitNumber: _selectedUnit,
                          user: widget.user,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _SubjectTile extends StatelessWidget {
  final SubjectModel subject;
  final VoidCallback onTap;
  const _SubjectTile({required this.subject, required this.onTap});

  static const Map<String, String> _icons = {
    'religion': '✝️',
    'scripture': '📖',
    'latin': '🏛️',
    'grammar': '✏️',
    'history': '🏰',
    'science': '🔬',
    'math': '➕',
    'geography': '🌍',
    'great_words_1': '💬',
    'great_words_2': '📝',
    'timeline': '⏳',
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_icons[subject.id] ?? '📚',
                  style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 4),
              Text(
                subject.name.length > 10
                    ? subject.name.split(' ').first
                    : subject.name,
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
  }
}
