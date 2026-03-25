// lib/widgets/lumen_home_panel.dart
// Animation 1: Lumen Home Panel — idle breathing loop.
// Level-based PNG asset: assets/lumen/lumen_home_level_{1-5}.png
// Tapping navigates to AchievementsScreen.
// Degrades gracefully to a ColoredBox if asset is missing.

import 'package:flutter/material.dart';
import '../utils/app_animations.dart';
import '../utils/app_theme.dart';

class LumenHomePanel extends StatefulWidget {
  final int level;          // 1–5
  final double width;       // default 160, class mode uses 260
  final VoidCallback? onTap;

  const LumenHomePanel({
    super.key,
    required this.level,
    this.width = 160.0,
    this.onTap,
  });

  @override
  State<LumenHomePanel> createState() => _LumenHomePanelState();
}

class _LumenHomePanelState extends State<LumenHomePanel>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _yAnim;
  // P2-4 polish: shadow blur + subtle horizontal sway
  late final Animation<double> _shadowBlurAnim;
  late final Animation<double> _swayAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: AppAnimations.lumenBreathePeriod,
    )..repeat(reverse: true);

    _scaleAnim = Tween<double>(begin: 1.0, end: AppAnimations.lumenBreatheScale)
        .animate(CurvedAnimation(
          parent: _controller,
          curve: AppAnimations.lumenBreatheCurve,
        ));

    _yAnim = Tween<double>(begin: 0.0, end: AppAnimations.lumenBreatheY)
        .animate(CurvedAnimation(
          parent: _controller,
          curve: AppAnimations.lumenBreatheCurve,
        ));

    // P2-4: shadow blur 8→14, sway rotate ±1°
    _shadowBlurAnim = Tween<double>(begin: 8.0, end: 14.0).animate(
      CurvedAnimation(parent: _controller, curve: AppAnimations.lumenBreatheCurve),
    );
    _swayAnim = Tween<double>(begin: -0.0175, end: 0.0175).animate(
      CurvedAnimation(parent: _controller, curve: AppAnimations.lumenBreatheCurve),
    );
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

  String get _assetPath {
    final l = widget.level.clamp(1, 5);
    return 'assets/lumen/lumen_home_level_$l.png';
  }

  @override
  Widget build(BuildContext context) {
    // Respect system accessibility setting
    if (MediaQuery.of(context).disableAnimations) {
      return _staticPanel(context);
    }

    return RepaintBoundary(
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _yAnim.value),
              child: Transform.rotate(
                angle: _swayAnim.value,
                child: Transform.scale(
                  scale: _scaleAnim.value,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.gold.withValues(alpha: 0.25),
                          blurRadius: _shadowBlurAnim.value,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: child,
                  ),
                ),
              ),
            );
          },
          child: _panelImage(context),
        ),
      ),
    );
  }

  Widget _staticPanel(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: _panelImage(context),
    );
  }

  Widget _panelImage(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.width,
      child: Image.asset(
        _assetPath,
        width: widget.width,
        height: widget.width,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: widget.width,
      height: widget.width,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.navy.withValues(alpha: 0.15),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.4), width: 2),
      ),
      child: Center(
        child: Icon(
          Icons.auto_awesome_rounded,
          size: widget.width * 0.4,
          color: AppTheme.gold.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
