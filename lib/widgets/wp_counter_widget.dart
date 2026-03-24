// lib/widgets/wp_counter_widget.dart
// Animated WP counter using AnimatedSwitcher + TweenAnimationBuilder.
// Shows current WP total; animates count-up when new WP arrives.
// Used in MemoryWorkHomeScreen header and AchievementsScreen.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../utils/app_animations.dart';
import '../utils/app_theme.dart';

class WPCounterWidget extends StatelessWidget {
  final int wp;
  final double fontSize;
  final bool showLabel;

  const WPCounterWidget({
    super.key,
    required this.wp,
    this.fontSize = 24.0,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          Icons.auto_awesome_rounded,
          color: AppTheme.gold,
          size: fontSize * 0.9,
        ),
        const SizedBox(width: 4),
        AnimatedSwitcher(
          duration: AppAnimations.wpPopInDuration,
          transitionBuilder: (child, animation) {
            return ScaleTransition(
              scale: CurvedAnimation(
                parent: animation,
                curve: AppAnimations.wpPopInCurve,
              ),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: Text(
            _formatWP(wp),
            key: ValueKey<int>(wp),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: AppTheme.gold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(width: 4),
          Text(
            'WP',
            style: TextStyle(
              fontSize: fontSize * 0.6,
              fontWeight: FontWeight.w600,
              color: AppTheme.gold.withValues(alpha: 0.8),
            ),
          ),
        ],
      ],
    );
  }

  String _formatWP(int value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return value.toString();
  }
}

/// Larger version for AchievementsScreen — shows WP with a level progress bar
class WPCounterWithProgressWidget extends StatelessWidget {
  final int wp;
  final int level;
  final int wpForNextLevel;

  const WPCounterWithProgressWidget({
    super.key,
    required this.wp,
    required this.level,
    required this.wpForNextLevel,
  });

  // WP thresholds matching memory_provider level-up logic
  static const List<int> _thresholds = [0, 200, 500, 1000, 1500, 9999];

  int get _wpAtCurrentLevel => _thresholds[level.clamp(0, 4)];
  int get _wpAtNextLevel => _thresholds[(level + 1).clamp(0, 5)];
  double get _progress {
    final range = _wpAtNextLevel - _wpAtCurrentLevel;
    if (range <= 0) return 1.0;
    return ((wp - _wpAtCurrentLevel) / range).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        WPCounterWidget(wp: wp, fontSize: 32),
        const SizedBox(height: 8),
        Text(
          'Level $level',
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.navy.withValues(alpha: 0.6),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: _progress),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: AppTheme.gold.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.gold),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        if (level < 5)
          Text(
            '${_wpAtNextLevel - wp} WP to Level ${level + 1}',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.navy.withValues(alpha: 0.5),
            ),
          )
        else
          Text(
            'Max Level!',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.gold,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}
