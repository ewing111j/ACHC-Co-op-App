import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../models/memory/memory_models.dart';
import '../../providers/memory_provider.dart';
import '../../utils/app_theme.dart';

class AchievementsScreen extends StatelessWidget {
  final UserModel user;
  const AchievementsScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        title: const Text('Achievements'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<MemoryProvider>(builder: (context, provider, _) {
        final achievements = provider.achievements;
        final earnedTypes =
            achievements.map((a) => a.achievementType).toSet();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Lumen panel summary
            if (provider.lumenState != null) ...[
              _LumenSummary(state: provider.lumenState!),
              const SizedBox(height: 20),
            ],

            const Text(
              'MEMORY MASTER MILESTONES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 10),

            // Subject achievements
            ...AchievementModel.labels.entries.map((entry) {
              final earned = earnedTypes.contains(entry.key);
              final achievementData = earned
                  ? achievements
                      .firstWhere((a) => a.achievementType == entry.key)
                  : null;
              return _AchievementTile(
                type: entry.key,
                label: entry.value,
                earned: earned,
                achievement: achievementData,
              );
            }),
          ],
        );
      }),
    );
  }
}

class _LumenSummary extends StatelessWidget {
  final LumenStateModel state;
  const _LumenSummary({required this.state});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Text(
              _emoji(state.lumenLevel),
              style: const TextStyle(fontSize: 40),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lumen — ${state.levelName}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppTheme.navy,
                    ),
                  ),
                  Text('Level ${state.lumenLevel} · ${state.totalWp} total WP',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: state.levelProgress.clamp(0.0, 1.0),
                      backgroundColor: Colors.grey[200],
                      color: AppTheme.gold,
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _emoji(int level) {
    const emojis = ['🕯️', '📜', '🎓', '⚔️', '👑'];
    return emojis[(level - 1).clamp(0, 4)];
  }
}

class _AchievementTile extends StatelessWidget {
  final String type;
  final String label;
  final bool earned;
  final AchievementModel? achievement;

  const _AchievementTile({
    required this.type,
    required this.label,
    required this.earned,
    this.achievement,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Icon(
          earned ? Icons.emoji_events : Icons.emoji_events_outlined,
          color: earned ? AppTheme.gold : Colors.grey[400],
          size: 28,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: earned ? Colors.black87 : Colors.black45,
          ),
        ),
        subtitle: earned && achievement != null
            ? Text(
                'Awarded ${_formatDate(achievement!.awardedAt)}',
                style: const TextStyle(fontSize: 12),
              )
            : const Text('Not yet earned',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: earned
            ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
            : const Icon(Icons.lock_outline, color: Colors.grey, size: 18),
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.month}/${d.day}/${d.year}';
  }
}
