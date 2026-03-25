// lib/widgets/lumen_hearts_bar.dart
//
// Renders Lumen's HP using pre-rendered whole-bar PNG assets.
// Assets live in assets/battle/:
//   hearts_5.png … hearts_0.png  — full / partial / empty bars
//   hearts_cracked_N.png         — cracked variant shown briefly after a hit
//
// Usage:
//   LumenHeartsBar(currentHp: _lumenHearts, maxHp: 5)
//
// The widget scales any maxHp to the 0-5 image set so gentle (7) and
// scholars (3) difficulty modes also map cleanly.

import 'package:flutter/material.dart';

class LumenHeartsBar extends StatefulWidget {
  final int currentHp;
  final int maxHp;       // actual max for this difficulty (3, 5, or 7)
  final double width;    // rendered width of the bar image

  const LumenHeartsBar({
    super.key,
    required this.currentHp,
    required this.maxHp,
    this.width = 140,
  });

  @override
  State<LumenHeartsBar> createState() => _LumenHeartsBarState();
}

class _LumenHeartsBarState extends State<LumenHeartsBar> {
  /// Slot we just lost — shows the cracked variant for 600 ms then clears.
  bool _showCracked = false;
  int _prevHp = -1;

  @override
  void didUpdateWidget(LumenHeartsBar old) {
    super.didUpdateWidget(old);
    if (widget.currentHp < old.currentHp && widget.currentHp > 0) {
      // A heart was just lost — flash the cracked image
      setState(() => _showCracked = true);
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _showCracked = false);
      });
    }
    _prevHp = old.currentHp;
  }

  /// Map any (currentHp, maxHp) pair onto the 0-5 image index.
  int get _slot {
    if (widget.maxHp <= 0) return 0;
    final ratio = widget.currentHp / widget.maxHp;
    return (ratio * 5).round().clamp(0, 5);
  }

  String get _assetPath {
    final slot = _slot;
    if (_showCracked && slot > 0) {
      return 'assets/battle/hearts_cracked_$slot.png';
    }
    return 'assets/battle/hearts_$slot.png';
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

  /// Emoji fallback if an asset is missing (should never happen in prod).
  Widget _fallback() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        widget.currentHp.clamp(0, 7),
        (_) => const Text('❤️', style: TextStyle(fontSize: 14)),
      ),
    );
  }
}
