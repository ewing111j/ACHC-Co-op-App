// lib/widgets/lumen_avatar.dart
// Animation 2: Lumen Avatar — glow pulse loop.
// Used in AppBar chips, ParentDashboard child cards, header rows.
// Level-based PNG: assets/lumen/lumen_avatar_level_{1-5}.png
// Glow color: gold for levels 1–3, purple for levels 4–5 (Phase 2 polish).

import 'package:flutter/material.dart';
import '../utils/app_animations.dart';
import '../utils/app_theme.dart';

class LumenAvatarWidget extends StatefulWidget {
  final int level;       // 1–5
  final double size;     // diameter of the avatar circle
  final VoidCallback? onTap;

  const LumenAvatarWidget({
    super.key,
    required this.level,
    this.size = 48.0,
    this.onTap,
  });

  @override
  State<LumenAvatarWidget> createState() => _LumenAvatarWidgetState();
}

class _LumenAvatarWidgetState extends State<LumenAvatarWidget>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  late final Animation<double> _glowAnim;
  // P2-4: inner glow ring at 180° phase offset
  late final Animation<double> _innerGlowAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: AppAnimations.lumenGlowPeriod,
    )..repeat(reverse: true);

    _glowAnim = Tween<double>(
      begin: AppAnimations.lumenGlowMinOpacity,
      end: AppAnimations.lumenGlowMaxOpacity,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    // P2-4: inner glow ring — reversed phase (min when outer is max)
    _innerGlowAnim = Tween<double>(
      begin: AppAnimations.lumenGlowMaxOpacity,
      end: AppAnimations.lumenGlowMinOpacity,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _controller.stop();
    } else if (state == AppLifecycleState.resumed) {
      _controller.repeat(reverse: true);
    }
  }

  Color get _glowColor {
    // Phase 2 polish: purple for levels 4–5
    return widget.level >= 4
        ? const Color(0xFF9C27B0)
        : AppTheme.gold;
  }

  String get _assetPath {
    final l = widget.level.clamp(1, 5);
    return 'assets/lumen/lumen_avatar_level_$l.png';
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return _staticAvatar();
    }

    return RepaintBoundary(
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _glowAnim,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // Outer glow ring
                Container(
                  width: widget.size + 8,
                  height: widget.size + 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _glowColor.withValues(alpha: _glowAnim.value),
                        blurRadius: AppAnimations.lumenGlowBlurRadius,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                // P2-4: Inner glow ring at 180° phase offset for depth
                Container(
                  width: widget.size - 4,
                  height: widget.size - 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _glowColor.withValues(
                            alpha: _innerGlowAnim.value * 0.5),
                        blurRadius: AppAnimations.lumenGlowBlurRadius * 0.5,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                // Avatar image
                Container(
                  width: widget.size,
                  height: widget.size,
                  child: child,
                ),
              ],
            );
          },
          child: ClipOval(
            child: Image.asset(
              _assetPath,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _staticAvatar() {
    return GestureDetector(
      onTap: widget.onTap,
      child: ClipOval(
        child: Image.asset(
          _assetPath,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: widget.size,
      height: widget.size,
      color: AppTheme.navy.withValues(alpha: 0.1),
      child: Icon(
        Icons.auto_awesome_rounded,
        size: widget.size * 0.5,
        color: _glowColor,
      ),
    );
  }
}
