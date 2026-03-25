// lib/utils/star_burst_painter.dart
// Custom painter for the level-up star burst effect.
// Used by LevelUpOverlay. Each ray is a thin line from center outward.

import 'dart:math' as math;
import 'package:flutter/material.dart';

class StarBurstPainter extends CustomPainter {
  final double progress; // 0.0 → 1.0 driven by AnimationController
  final Color color;
  final int rayCount;
  final double maxRadius;

  StarBurstPainter({
    required this.progress,
    this.color = const Color(0xFFC9A84C), // AppTheme.gold
    this.rayCount = 12,
    this.maxRadius = 80.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final angleStep = (2 * math.pi) / rayCount;

    final paint = Paint()
      ..color = color.withValues(alpha: (1.0 - progress) * 0.9)
      ..strokeWidth = 3.0 * (1.0 - progress * 0.5)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final innerRadius = maxRadius * 0.15;
    final outerRadius = maxRadius * progress;

    for (int i = 0; i < rayCount; i++) {
      final angle = angleStep * i - math.pi / 2;
      final start = Offset(
        center.dx + innerRadius * math.cos(angle),
        center.dy + innerRadius * math.sin(angle),
      );
      final end = Offset(
        center.dx + outerRadius * math.cos(angle),
        center.dy + outerRadius * math.sin(angle),
      );
      canvas.drawLine(start, end, paint);

      // Trailing dot along each ray
      final trailPaint = Paint()
        ..color = color.withValues(alpha: (1.0 - progress) * 0.5)
        ..style = PaintingStyle.fill;
      final trailRadius = 3.0 * (1.0 - progress);
      if (trailRadius > 0) {
        canvas.drawCircle(end, trailRadius, trailPaint);
      }
    }
  }

  @override
  bool shouldRepaint(StarBurstPainter old) =>
      old.progress != progress || old.color != color;
}

/// Compact version used for battle projectile impact burst (20 px scale)
class MiniStarBurstPainter extends CustomPainter {
  final double progress;
  final Color color;

  const MiniStarBurstPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    const rayCount = 4;
    const maxR = 10.0;
    final paint = Paint()
      ..color = color.withValues(alpha: 1.0 - progress)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < rayCount; i++) {
      final angle = (math.pi / 2 * i) - math.pi / 4;
      canvas.drawLine(
        center,
        Offset(
          center.dx + maxR * progress * math.cos(angle),
          center.dy + maxR * progress * math.sin(angle),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(MiniStarBurstPainter old) => old.progress != progress;
}
