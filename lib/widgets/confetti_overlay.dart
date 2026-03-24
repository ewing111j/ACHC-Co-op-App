// lib/widgets/confetti_overlay.dart
// Animation 13: "We Practiced!" confetti burst for YoungLearnerContentCard.
// Mounted as OverlayEntry so it renders above DraggableScrollableSheet dismiss.
// Uses only Flutter primitives + flutter_animate (no confetti package).

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_animations.dart';
import '../utils/app_theme.dart';

/// Call from YoungLearnerContentCard on "We Practiced!" button tap.
void showConfettiOverlay(BuildContext context) {
  HapticFeedback.mediumImpact();
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => ConfettiOverlay(
      onComplete: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );
  Overlay.of(context).insert(entry);
}

class ConfettiOverlay extends StatefulWidget {
  final VoidCallback onComplete;

  const ConfettiOverlay({super.key, required this.onComplete});

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_ConfettoPiece> _pieces;
  final _random = math.Random();

  static const List<Color> _colors = [
    AppTheme.gold,
    Color(0xFF1B2A4A), // navy
    Color(0xFFE53935), // red
    Color(0xFF43A047), // green
    Color(0xFF1E88E5), // blue
    Color(0xFFFFB300), // amber
    Colors.white,
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppAnimations.confettiDuration,
    );

    _pieces = List.generate(AppAnimations.confettiCount, (i) {
      final isCircle = i % 6 == 0; // mix in circle pieces
      return _ConfettoPiece(
        x: _random.nextDouble(),
        color: _colors[_random.nextInt(_colors.length)],
        size: 6.0 + _random.nextDouble() * 8.0,
        speedY: 0.4 + _random.nextDouble() * 0.6,
        speedX: (_random.nextDouble() - 0.5) * 0.4,
        rotationSpeed: (_random.nextDouble() - 0.5) * 6.0,
        isCircle: isCircle,
        delay: _random.nextDouble() * 0.3,
      );
    });

    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final size = MediaQuery.of(context).size;
          return Stack(
            children: _pieces.map((piece) {
              final t = (_controller.value - piece.delay)
                  .clamp(0.0, 1.0) / (1.0 - piece.delay).clamp(0.01, 1.0);
              if (t <= 0) return const SizedBox.shrink();

              final x = (piece.x + piece.speedX * t) * size.width;
              final y = -20.0 + piece.speedY * size.height * t;
              final opacity = t < 0.8 ? 1.0 : (1.0 - t) / 0.2;
              final rotation = piece.rotationSpeed * t;

              return Positioned(
                left: x,
                top: y,
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Transform.rotate(
                    angle: rotation,
                    child: piece.isCircle
                        ? Container(
                            width: piece.size,
                            height: piece.size,
                            decoration: BoxDecoration(
                              color: piece.color,
                              shape: BoxShape.circle,
                            ),
                          )
                        : Container(
                            width: piece.size,
                            height: piece.size * 0.5,
                            color: piece.color,
                          ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _ConfettoPiece {
  final double x;
  final Color color;
  final double size;
  final double speedY;
  final double speedX;
  final double rotationSpeed;
  final bool isCircle;
  final double delay;

  const _ConfettoPiece({
    required this.x,
    required this.color,
    required this.size,
    required this.speedY,
    required this.speedX,
    required this.rotationSpeed,
    required this.isCircle,
    required this.delay,
  });
}
