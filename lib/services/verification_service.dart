// lib/services/verification_service.dart
//
// P3-1: Scores a student's spoken recitation against the target text.
//
// Thresholds are intentionally generous — this is a practice aid, not an exam.
// Admins can adjust the pass threshold in Firestore (memory_settings doc).

import 'package:shared_preferences/shared_preferences.dart';
import '../utils/string_similarity.dart';

// ── Result model ─────────────────────────────────────────────────────────────

enum ReciteOutcome { pass, partial, fail, fallback }

class VerificationResult {
  final ReciteOutcome outcome;
  final double scorePercent;   // 0–100
  final int wpBonus;           // WP to award (0 for fail/fallback)
  final List<WordMatch> diff;  // word-by-word match breakdown
  final String transcript;     // what the STT heard

  const VerificationResult({
    required this.outcome,
    required this.scorePercent,
    required this.wpBonus,
    required this.diff,
    required this.transcript,
  });

  bool get isPassing => outcome == ReciteOutcome.pass || outcome == ReciteOutcome.partial;

  String get outcomeLine {
    switch (outcome) {
      case ReciteOutcome.pass:
        return 'Excellent! Keep it up! ⭐';
      case ReciteOutcome.partial:
        return 'Almost there! Keep practising 🔥';
      case ReciteOutcome.fail:
        return 'Keep working on it 🌱';
      case ReciteOutcome.fallback:
        return 'Could not hear clearly — did you say it correctly?';
    }
  }
}

// ── Service ───────────────────────────────────────────────────────────────────

class VerificationService {
  // SharedPreferences key for admin-configurable pass threshold
  static const _keyPassThreshold = 'recite_pass_threshold';
  static const _keyPartialThreshold = 'recite_partial_threshold';

  // Default thresholds (percent word overlap required)
  static const double _defaultPassThreshold = 0.85;
  static const double _defaultPartialThreshold = 0.65;

  // WP bonuses for each outcome
  static const int _wpPass = 5;
  static const int _wpPartial = 2;
  static const int _wpFallbackSelf = 3; // self-reported correct
  static const int _wpFallbackMiss = 0; // self-reported incorrect

  /// Load thresholds (admin can override via SharedPreferences / Firestore sync)
  static Future<({double pass, double partial})> loadThresholds() async {
    final prefs = await SharedPreferences.getInstance();
    final pass = prefs.getDouble(_keyPassThreshold) ?? _defaultPassThreshold;
    final partial = prefs.getDouble(_keyPartialThreshold) ?? _defaultPartialThreshold;
    return (pass: pass, partial: partial);
  }

  /// Persist admin-configured thresholds locally
  static Future<void> saveThresholds({
    required double pass,
    required double partial,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyPassThreshold, pass);
    await prefs.setDouble(_keyPartialThreshold, partial);
  }

  /// Main scoring method.
  /// [target]     — the canonical memory item text
  /// [transcript] — what speech_to_text returned (may be empty)
  /// Returns a [VerificationResult] with outcome, score, WP bonus, and word diff.
  static Future<VerificationResult> score({
    required String target,
    required String transcript,
  }) async {
    // Empty transcript → STT failed → offer fallback self-check
    if (transcript.trim().isEmpty) {
      return VerificationResult(
        outcome: ReciteOutcome.fallback,
        scorePercent: 0,
        wpBonus: 0,
        diff: StringSimilarity.diff(target, ''),
        transcript: '',
      );
    }

    final thresholds = await loadThresholds();
    final raw = StringSimilarity.score(target, transcript);
    final percent = (raw * 100).roundToDouble();
    final wordDiff = StringSimilarity.diff(target, transcript);

    ReciteOutcome outcome;
    int wpBonus;

    if (raw >= thresholds.pass) {
      outcome = ReciteOutcome.pass;
      wpBonus = _wpPass;
    } else if (raw >= thresholds.partial) {
      outcome = ReciteOutcome.partial;
      wpBonus = _wpPartial;
    } else {
      outcome = ReciteOutcome.fail;
      wpBonus = 0;
    }

    return VerificationResult(
      outcome: outcome,
      scorePercent: percent,
      wpBonus: wpBonus,
      diff: wordDiff,
      transcript: transcript,
    );
  }

  /// Called when STT fails and the student taps the self-report buttons.
  static VerificationResult fallbackResult({
    required String target,
    required bool selfReportedCorrect,
  }) {
    return VerificationResult(
      outcome: selfReportedCorrect ? ReciteOutcome.partial : ReciteOutcome.fail,
      scorePercent: selfReportedCorrect ? 100 : 0,
      wpBonus: selfReportedCorrect ? _wpFallbackSelf : _wpFallbackMiss,
      diff: StringSimilarity.diff(target, selfReportedCorrect ? target : ''),
      transcript: '(self-reported)',
    );
  }
}
