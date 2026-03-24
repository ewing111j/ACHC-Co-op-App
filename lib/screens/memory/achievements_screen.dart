import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/user_model.dart';
import '../../models/memory/memory_models.dart';
import '../../providers/memory_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_animations.dart';
import '../../widgets/lumen_home_panel.dart';
import '../../widgets/wp_counter_widget.dart';

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

            // Subject achievements — staggered entrance animation
            ...AchievementModel.labels.entries.toList().asMap().entries.map((entry) {
              final i = entry.key;
              final mapEntry = entry.value;
              final earned = earnedTypes.contains(mapEntry.key);
              final achievementData = earned
                  ? achievements
                      .firstWhere((a) => a.achievementType == mapEntry.key)
                  : null;
              return _AchievementTile(
                type: mapEntry.key,
                label: mapEntry.value,
                earned: earned,
                achievement: achievementData,
                animationIndex: i,
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
            // Animated Lumen Avatar (Animation 2)
            LumenHomePanel(
              level: state.lumenLevel,
              width: 72,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: WPCounterWithProgressWidget(
                wp: state.totalWp,
                level: state.lumenLevel,
                wpForNextLevel: state.wpNeededForNextLevel,
              ),
            ),
          ],
        ),
      ),
    ).animate()
        .fadeIn(duration: AppAnimations.cardFadeInDuration)
        .moveY(begin: AppAnimations.cardEntranceMoveY, end: 0,
               duration: AppAnimations.cardFadeInDuration);
  }
}

class _AchievementTile extends StatelessWidget {
  final String type;
  final String label;
  final bool earned;
  final AchievementModel? achievement;
  final int animationIndex;

  const _AchievementTile({
    required this.type,
    required this.label,
    required this.earned,
    this.achievement,
    this.animationIndex = 0,
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
    ).animate(
      delay: AppAnimations.staggerItemDelay * animationIndex,
    ).fadeIn().scale(
      begin: const Offset(0.95, 0.95),
      end: const Offset(1.0, 1.0),
      duration: AppAnimations.cardFadeInDuration,
    );
  }

  String _formatDate(DateTime d) {
    return '${d.month}/${d.day}/${d.year}';
  }
}
