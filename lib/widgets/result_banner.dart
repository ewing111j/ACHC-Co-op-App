// lib/widgets/result_banner.dart
//
// P3-1: Animated banner shown after a recitation attempt.
//
// Shows:
//   • Colour-coded outcome (green / amber / red)
//   • Score percentage
//   • Word-by-word diff (green = heard, red = missed)
//   • WP bonus earned
//   • Fallback self-report buttons when STT could not transcribe

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/verification_service.dart';
import '../utils/app_theme.dart';
import '../utils/string_similarity.dart';

class ResultBanner extends StatelessWidget {
  final VerificationResult result;

  /// Called after a fallback self-report button is tapped.
  /// Passes the corrected result back to the parent.
  final ValueChanged<VerificationResult>? onFallbackSelected;

  /// The target text — needed to build the fallback result
  final String target;

  const ResultBanner({
    super.key,
    required this.result,
    required this.target,
    this.onFallbackSelected,
  });

  // ── Styling helpers ─────────────────────────────────────────────────────────

  Color get _bgColor {
    switch (result.outcome) {
      case ReciteOutcome.pass:
        return const Color(0xFFE8F5E9); // green tint
      case ReciteOutcome.partial:
        return const Color(0xFFFFF8E1); // amber tint
      case ReciteOutcome.fail:
        return const Color(0xFFFFEBEE); // red tint
      case ReciteOutcome.fallback:
        return const Color(0xFFF3E5F5); // purple tint
    }
  }

  Color get _accentColor {
    switch (result.outcome) {
      case ReciteOutcome.pass:
        return const Color(0xFF2E7D32);
      case ReciteOutcome.partial:
        return const Color(0xFFF57F17);
      case ReciteOutcome.fail:
        return const Color(0xFFC62828);
      case ReciteOutcome.fallback:
        return const Color(0xFF6A1B9A);
    }
  }

  IconData get _icon {
    switch (result.outcome) {
      case ReciteOutcome.pass:
        return Icons.check_circle_outline;
      case ReciteOutcome.partial:
        return Icons.thumbs_up_down_outlined;
      case ReciteOutcome.fail:
        return Icons.replay_outlined;
      case ReciteOutcome.fallback:
        return Icons.hearing_disabled_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _accentColor.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ────────────────────────────────────────────────────
          Row(
            children: [
              Icon(_icon, color: _accentColor, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.outcomeLine,
                  style: TextStyle(
                    color: _accentColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              if (result.outcome != ReciteOutcome.fallback) ...[
                Text(
                  '${result.scorePercent.toInt()}%',
                  style: TextStyle(
                    color: _accentColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
              ],
            ],
          ),

          // ── WP bonus ──────────────────────────────────────────────────────
          if (result.wpBonus > 0) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const SizedBox(width: 30),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.gold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.gold.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    '+${result.wpBonus} WP',
                    style: TextStyle(
                      color: AppTheme.gold.withValues(alpha: 1.0),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // ── Word diff ─────────────────────────────────────────────────────
          if (result.outcome != ReciteOutcome.fallback &&
              result.diff.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Words heard:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            _WordDiffRow(diff: result.diff),
          ],

          // ── Fallback self-report ───────────────────────────────────────────
          if (result.outcome == ReciteOutcome.fallback &&
              onFallbackSelected != null) ...[
            const SizedBox(height: 14),
            const Text(
              'Did you say it correctly?',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onFallbackSelected!(
                      VerificationService.fallbackResult(
                        target: target,
                        selfReportedCorrect: true,
                      ),
                    ),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Yes, I did'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2E7D32),
                      side: const BorderSide(color: Color(0xFF2E7D32)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onFallbackSelected!(
                      VerificationService.fallbackResult(
                        target: target,
                        selfReportedCorrect: false,
                      ),
                    ),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Not quite'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFC62828),
                      side: const BorderSide(color: Color(0xFFC62828)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    )
        .animate()
        .slideY(begin: 0.2, duration: 280.ms, curve: Curves.easeOut)
        .fadeIn(duration: 280.ms);
  }
}

// ── Word diff chip row ────────────────────────────────────────────────────────

class _WordDiffRow extends StatelessWidget {
  final List<WordMatch> diff;
  const _WordDiffRow({required this.diff});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: diff.map((w) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: w.matched
                ? const Color(0xFFE8F5E9)
                : const Color(0xFFFFEBEE),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: w.matched
                  ? const Color(0xFF66BB6A)
                  : const Color(0xFFEF9A9A),
            ),
          ),
          child: Text(
            w.word,
            style: TextStyle(
              fontSize: 12,
              color: w.matched
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFFC62828),
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }
}
