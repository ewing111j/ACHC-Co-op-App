// lib/widgets/enemy_orbs_bar.dart
//
// Renders the enemy's HP using pre-rendered whole-bar PNG assets.
// Assets live in assets/battle/:
//   orbs_5.png … orbs_0.png      — full → empty bars (5-slot scale)
//   orbs_cracked_4.png           — cracked flash for 4-slot hit
//   orbs_cracked_1.png           — cracked flash for critical last orb
//   orbs_cracked.png             — generic cracked flash (fallback)
//
// Enemy orb counts range from 3–6 depending on difficulty/unit progress.
// All counts are scaled onto the 0-5 image set via ratio mapping.
//
// Usage:
//   EnemyOrbsBar(currentOrbs: _enemyOrbs, maxOrbs: widget.enemyOrbs)

import 'package:flutter/material.dart';

class EnemyOrbsBar extends StatefulWidget {
  final int currentOrbs;
  final int maxOrbs;     // initial orb count (3–6)
  final double width;

  const EnemyOrbsBar({
    super.key,
    required this.currentOrbs,
    required this.maxOrbs,
    this.width = 140,
  });

  @override
  State<EnemyOrbsBar> createState() => _EnemyOrbsBarState();
}

class _EnemyOrbsBarState extends State<EnemyOrbsBar> {
  bool _showCracked = false;

  @override
  void didUpdateWidget(EnemyOrbsBar old) {
    super.didUpdateWidget(old);
    if (widget.currentOrbs < old.currentOrbs && widget.currentOrbs > 0) {
      setState(() => _showCracked = true);
      Future.delayed(const Duration(milliseconds: 650), () {
        if (mounted) setState(() => _showCracked = false);
      });
    }
  }

  /// Map current orbs onto 0–5 image slot.
  int get _slot {
    if (widget.maxOrbs <= 0) return 0;
    final ratio = widget.currentOrbs / widget.maxOrbs;
    return (ratio * 5).round().clamp(0, 5);
  }

  String get _assetPath {
    final slot = _slot;
    if (_showCracked && slot > 0) {
      // Use slot-specific cracked image where available, else generic
      if (slot == 4) return 'assets/battle/orbs_cracked_4.png';
      if (slot == 1) return 'assets/battle/orbs_cracked_1.png';
      return 'assets/battle/orbs_cracked.png';
    }
    return 'assets/battle/orbs_$slot.png';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Image.asset(
        _assetPath,
        key: ValueKey(_assetPath),
        width: widget.width,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _fallback(),
      ),
    );
  }

  Widget _fallback() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        widget.currentOrbs.clamp(0, 6),
        (_) => const Text('🔮', style: TextStyle(fontSize: 14)),
      ),
    );
  }
}
