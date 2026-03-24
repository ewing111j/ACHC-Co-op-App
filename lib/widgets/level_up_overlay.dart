// lib/widgets/level_up_overlay.dart
// Animation 3: Level-Up sequence — shown as an OverlayEntry above the current
// route when memory_provider.levelUpNotifier fires a new level value.
// Star burst + scale + flash + "NEW LEVEL n!" badge.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../utils/app_animations.dart';
import '../utils/app_theme.dart';
import '../utils/star_burst_painter.dart';

/// Call this from MemoryWorkHomeScreen (or any screen) when level-up fires.
/// Inserts an OverlayEntry and auto-removes after the animation completes.
void showLevelUpOverlay(BuildContext context, int newLevel) {
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => LevelUpOverlay(
      newLevel: newLevel,
      onComplete: () => entry.remove(),
    ),
  );
  Overlay.of(context).insert(entry);
}

class LevelUpOverlay extends StatefulWidget {
  final int newLevel;
  final VoidCallback onComplete;

  const LevelUpOverlay({
    super.key,
    required this.newLevel,
    required this.onComplete,
  });

  @override
  State<LevelUpOverlay> createState() => _LevelUpOverlayState();
}

class _LevelUpOverlayState extends State<LevelUpOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _starController;
  bool _showBadge = false;

  @override
  void initState() {
    super.initState();

    _starController = AnimationController(
      vsync: this,
      duration: AppAnimations.levelUpStarDuration,
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    // Step 1: star burst
    await _starController.forward();
    // Step 2: show badge after burst
    if (mounted) setState(() => _showBadge = true);
    // Step 3: hold
    await Future.delayed(const Duration(milliseconds: 1500));
    // Step 4: dismiss
    if (mounted) widget.onComplete();
  }

  @override
  void dispose() {
    _starController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return _staticFallback(context);
    }

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Dim background
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onComplete,
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
              ),
            ),
          ),
          // Star burst
          Center(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _starController,
                builder: (context, _) {
                  return CustomPaint(
                    size: const Size(200, 200),
                    painter: StarBurstPainter(
                      progress: _starController.value,
                      color: AppTheme.gold,
                      rayCount: 14,
                      maxRadius: 100,
                    ),
                  );
                },
              ),
            ),
          ),
          // Level badge
          Center(
            child: AnimatedOpacity(
              opacity: _showBadge ? 1.0 : 0.0,
              duration: AppAnimations.levelUpFlashDuration,
              child: _showBadge
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '✨',
                          style: const TextStyle(fontSize: 48),
                        ).animate().scale(
                          begin: const Offset(0.3, 0.3),
                          end: const Offset(1, 1),
                          duration: AppAnimations.levelUpScaleDuration,
                          curve: AppAnimations.levelUpScaleCurve,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.gold,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.gold.withValues(alpha: 0.4),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Text(
                            'NEW LEVEL ${widget.newLevel}!',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1.5,
                            ),
                          ),
                        )
                            .animate()
                            .moveY(
                              begin: 10,
                              end: 0,
                              duration:
                                  AppAnimations.levelUpCountDuration,
                              curve: Curves.easeOut,
                            )
                            .fadeIn(
                              duration: AppAnimations.levelUpCountDuration,
                            ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _staticFallback(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Center(
        child: GestureDetector(
          onTap: widget.onComplete,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            decoration: BoxDecoration(
              color: AppTheme.gold,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'NEW LEVEL ${widget.newLevel}!',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
