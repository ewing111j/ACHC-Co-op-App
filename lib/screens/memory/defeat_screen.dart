// lib/screens/memory/defeat_screen.dart
// Animation 10: Defeat — mist fade + desaturation effect.
// No WP award on defeat.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/user_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_animations.dart';
import '../../utils/battle_assets.dart';

class DefeatScreen extends StatelessWidget {
  final UserModel user;
  final String enemyName;

  const DefeatScreen({
    super.key,
    required this.user,
    required this.enemyName,
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return _StaticDefeat(user: user, enemyName: enemyName);
    }

    return Scaffold(
      body: Stack(
        children: [
          // Defeat background — dark library fading to mist (Animation 10)
          Positioned.fill(
            child: Image.asset(
              BattleAssets.defeatBg,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.blueGrey[900]),
            ).animate()
                .fadeIn(duration: AppAnimations.defeatMistDuration),
          ),
          // Desaturation overlay
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: const ColorFilter.matrix([
                0.2126, 0.7152, 0.0722, 0, 0,
                0.2126, 0.7152, 0.0722, 0, 0,
                0.2126, 0.7152, 0.0722, 0, 0,
                0,      0,      0,      0.5, 0,
              ]),
              child: Container(color: Colors.transparent),
            ),
          ),
          // Dim overlay (Animation 10 — mist fade)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: AppAnimations.defeatDimOpacity),
            ).animate().fadeIn(duration: AppAnimations.defeatMistDuration),
          ),
          // Content
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🌑', style: TextStyle(fontSize: 72))
                        .animate()
                        .fadeIn(duration: AppAnimations.defeatMistDuration)
                        .scale(
                          begin: const Offset(1.3, 1.3),
                          end: const Offset(1.0, 1.0),
                          duration: AppAnimations.defeatMistDuration,
                        ),
                    const SizedBox(height: 20),
                    const Text(
                      'Lumen Retreats...',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ).animate(
                          delay: const Duration(milliseconds: 300),
                        )
                        .fadeIn()
                        .shake(
                          hz: 2,
                          offset: const Offset(6, 0),
                          duration: AppAnimations.defeatShakeDuration,
                        ),
                    const SizedBox(height: 12),
                    Text(
                      '$enemyName was too powerful this time.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ).animate(delay: const Duration(milliseconds: 500))
                        .fadeIn(),
                    const SizedBox(height: 16),
                    Text(
                      'Keep studying and try again!',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.5),
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ).animate(delay: const Duration(milliseconds: 700))
                        .fadeIn(),
                    const SizedBox(height: 48),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.pop(context);
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.5)),
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Try Again'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context)
                                .popUntil((r) => r.isFirst),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.9),
                              foregroundColor: Colors.blueGrey[900],
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Return Home',
                                style:
                                    TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ).animate(
                          delay: const Duration(milliseconds: 800),
                        )
                        .fadeIn(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaticDefeat extends StatelessWidget {
  final UserModel user;
  final String enemyName;
  const _StaticDefeat({required this.user, required this.enemyName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[900],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🌑', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 16),
            const Text('Lumen Retreats...',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
            const SizedBox(height: 8),
            const Text('Keep studying and try again!',
                style:
                    TextStyle(fontSize: 15, color: Colors.white70)),
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
