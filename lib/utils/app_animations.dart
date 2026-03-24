// lib/utils/app_animations.dart
// Single source of truth for all animation durations, curves, and offsets.
// All animation widgets import from here — never hardcode values in widgets.
// Version: 2.1 — flutter_animate ^4.5.0 only. No Rive, no Lottie.

import 'package:flutter/material.dart';

class AppAnimations {
  AppAnimations._();

  // ── Lumen Home Panel (idle breathing loop) ───────────────────────────────
  static const Duration lumenBreathePeriod  = Duration(milliseconds: 3200);
  static const double   lumenBreatheY       = -6.0; // px upward at peak
  static const double   lumenBreatheScale   = 1.03;
  static const Curve    lumenBreatheCurve   = Curves.easeInOut;

  // ── Lumen Avatar (glow pulse loop) ───────────────────────────────────────
  static const Duration lumenGlowPeriod     = Duration(milliseconds: 2400);
  static const double   lumenGlowMinOpacity = 0.25;
  static const double   lumenGlowMaxOpacity = 0.80;
  static const double   lumenGlowBlurRadius = 28.0;

  // ── Level-Up Sequence ─────────────────────────────────────────────────────
  static const Duration levelUpScaleDuration = Duration(milliseconds: 450);
  static const Duration levelUpFlashDuration = Duration(milliseconds: 200);
  static const Duration levelUpStarDuration  = Duration(milliseconds: 600);
  static const Duration levelUpCountDuration = Duration(milliseconds: 800);
  static const Curve    levelUpScaleCurve    = Curves.elasticOut;

  // ── Victory / Defeat Screens ──────────────────────────────────────────────
  static const Duration victoryBounceDuration = Duration(milliseconds: 520);
  static const Duration victoryShimmerPeriod  = Duration(milliseconds: 1600);
  static const Duration victoryScreenSplash   = Duration(milliseconds: 500);
  static const Duration defeatShakeDuration   = Duration(milliseconds: 400);
  static const Duration defeatMistDuration    = Duration(milliseconds: 700);
  static const double   defeatDimOpacity      = 0.45;

  // ── WP Pop-In ─────────────────────────────────────────────────────────────
  static const Duration wpPopInDuration = Duration(milliseconds: 350);
  static const Curve    wpPopInCurve    = Curves.elasticOut;

  // ── Battle – Enemy Entrance ───────────────────────────────────────────────
  static const Duration enemyEnterDuration  = Duration(milliseconds: 380);
  static const double   enemyEnterOffsetX   = 120.0; // px slide from right
  static const Curve    enemyEnterCurve     = Curves.easeOutCubic;

  // ── Battle – Enemy Hit ────────────────────────────────────────────────────
  static const Duration enemyHitFlashDuration = Duration(milliseconds: 100);
  static const Duration enemyHitShakeDuration = Duration(milliseconds: 300);
  static const double   enemyHitShakeOffset   = 8.0;

  // ── Battle – Lumen Attack Projectile ──────────────────────────────────────
  static const Duration projectileDuration = Duration(milliseconds: 420);
  static const double   projectileSize     = 20.0; // diameter px

  // ── Audio Button Pulse ────────────────────────────────────────────────────
  static const Duration audioPulsePeriod = Duration(milliseconds: 1000);
  static const double   audioPulseScale  = 1.14;

  // ── Subject Icon Tap ──────────────────────────────────────────────────────
  static const Duration subjectTapDuration = Duration(milliseconds: 260);
  static const double   subjectTapScale    = 1.18;

  // ── "We Practiced!" Confetti ──────────────────────────────────────────────
  static const Duration confettiDuration = Duration(milliseconds: 1200);
  static const int      confettiCount    = 24;

  // ── Navigation Transitions ────────────────────────────────────────────────
  static const Duration navTransitionDuration  = Duration(milliseconds: 280);
  static const double   navSlideY              = 18.0; // px upward slide
  static const Duration classModeZoomDuration  = Duration(milliseconds: 340);
  static const Curve    classModeZoomCurve     = Curves.easeInOut;

  // ── Card / List Entrance ──────────────────────────────────────────────────
  static const Duration cardFadeInDuration     = Duration(milliseconds: 300);
  static const Duration staggerItemDelay       = Duration(milliseconds: 80);
  static const double   cardEntranceMoveY      = 12.0;

  // ── Week-Change AnimatedSwitcher ──────────────────────────────────────────
  static const Duration weekChangeDuration     = Duration(milliseconds: 200);

  // ── Coverage status chip ──────────────────────────────────────────────────
  static const Duration statusChipDuration     = Duration(milliseconds: 200);

  // ── Button scale tap ─────────────────────────────────────────────────────
  static const Duration buttonTapDuration      = Duration(milliseconds: 220);
  static const Curve    buttonTapCurve         = Curves.bounceOut;
}
