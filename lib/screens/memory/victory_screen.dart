// lib/screens/memory/victory_screen.dart
// Animation 9: Victory splash — scale + WP pop-in.
// Shown after defeating a battle enemy.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/user_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_animations.dart';
import '../../widgets/wp_counter_widget.dart';

class VictoryScreen extends StatelessWidget {
  final UserModel user;
  final int wpEarned;
  final String enemyName;

  const VictoryScreen({
    super.key,
    required this.user,
    required this.wpEarned,
    required this.enemyName,
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return _StaticVictory(
          user: user, wpEarned: wpEarned, enemyName: enemyName);
    }

    return Scaffold(
      backgroundColor: AppTheme.navy,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Victory star splash (Animation 9)
                const Text('⭐', style: TextStyle(fontSize: 80))
                    .animate()
                    .scale(
                      begin: const Offset(0.2, 0.2),
                      end: const Offset(1.0, 1.0),
                      duration: AppAnimations.victoryScreenSplash,
                      curve: AppAnimations.levelUpScaleCurve,
                    )
                    .then()
                    .shimmer(
                      duration: AppAnimations.victoryShimmerPeriod,
                      color: AppTheme.gold.withValues(alpha: 0.6),
                    ),
                const SizedBox(height: 24),
                const Text(
                  'VICTORY!',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 3,
                  ),
                ).animate(delay: const Duration(milliseconds: 200))
                    .fadeIn()
                    .moveY(begin: 20, end: 0),
                const SizedBox(height: 12),
                Text(
                  'You defeated $enemyName!',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                  textAlign: TextAlign.center,
                ).animate(delay: const Duration(milliseconds: 300)).fadeIn(),
                const SizedBox(height: 32),
                // WP earned pop-in (Animation 9 — WP badge)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.gold,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.gold.withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Wisdom Points Earned',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      WPCounterWidget(
                        wp: wpEarned,
                        fontSize: 36,
                        showLabel: false,
                      ),
                    ],
                  ),
                ).animate(delay: AppAnimations.victoryBounceDuration)
                    .scale(
                      begin: const Offset(0.5, 0.5),
                      duration: AppAnimations.wpPopInDuration,
                      curve: AppAnimations.wpPopInCurve,
                    )
                    .fadeIn(duration: AppAnimations.wpPopInDuration),
                const SizedBox(height: 48),
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          // Pop back to BattleEntry for another battle
                          Navigator.pop(context);
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white54),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Battle Again'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context)
                            .popUntil((r) => r.isFirst),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.navy,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Return Home',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ).animate(delay: const Duration(milliseconds: 600)).fadeIn(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StaticVictory extends StatelessWidget {
  final UserModel user;
  final int wpEarned;
  final String enemyName;
  const _StaticVictory(
      {required this.user, required this.wpEarned, required this.enemyName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navy,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('⭐', style: TextStyle(fontSize: 80)),
            const SizedBox(height: 16),
            const Text('VICTORY!',
                style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: Colors.white)),
            const SizedBox(height: 8),
            Text('+$wpEarned WP',
                style: const TextStyle(fontSize: 24, color: Color(0xFFC9A84C))),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).popUntil((r) => r.isFirst),
              child: const Text('Return Home'),
            ),
          ],
        ),
      ),
    );
  }
}
