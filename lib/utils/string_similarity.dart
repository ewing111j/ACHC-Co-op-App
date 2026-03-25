// lib/utils/string_similarity.dart
//
// P3-1: Token-overlap similarity scorer for speech-to-text verification.
//
// Design rationale (see Phase 3 design doc):
//  • Raw Levenshtein is unfair for 10–40 word strings — one mis-heard word
//    costs 15+ character edits.
//  • Word-token Jaccard / overlap coefficient matches how a teacher would
//    grade a recitation: "did you say the right words?" not "was every
//    character perfect?".
//  • Filler-word stripping, punctuation removal, and a proper-noun alias map
//    all reduce false negatives for children's speech.

class StringSimilarity {
  // ── Public API ──────────────────────────────────────────────────────────────

  /// Returns a score in [0.0, 1.0] representing how closely [heard] matches
  /// [target]. Uses word-token overlap coefficient (# shared tokens / # target
  /// tokens), so a student who says every target word correctly scores 1.0
  /// even if they add a few filler words.
  static double score(String target, String heard) {
    final targetTokens = _tokenise(target);
    final heardTokens = _tokenise(heard);

    if (targetTokens.isEmpty) return 1.0; // nothing to check
    if (heardTokens.isEmpty) return 0.0;

    // Apply alias map: replace known STT mis-hearings in heard tokens
    final normHeard = heardTokens.map(_applyAliases).toList();

    // Count matched tokens (allow each target token to match at most once)
    final heardCopy = List<String>.from(normHeard);
    int matched = 0;
    for (final word in targetTokens) {
      final idx = heardCopy.indexOf(word);
      if (idx != -1) {
        matched++;
        heardCopy.removeAt(idx);
      }
    }

    // Overlap coefficient: matched / |target| — tolerates extra filler words
    return matched / targetTokens.length;
  }

  /// Returns a human-readable diff: list of target words with whether each
  /// was heard. Useful for the result banner to highlight missed words.
  static List<WordMatch> diff(String target, String heard) {
    final targetTokens = _tokenise(target);
    final heardCopy = _tokenise(heard).map(_applyAliases).toList();

    final result = <WordMatch>[];
    for (final word in targetTokens) {
      final idx = heardCopy.indexOf(word);
      if (idx != -1) {
        heardCopy.removeAt(idx);
        result.add(WordMatch(word: word, matched: true));
      } else {
        result.add(WordMatch(word: word, matched: false));
      }
    }
    return result;
  }

  // ── Tokenisation ────────────────────────────────────────────────────────────

  static List<String> _tokenise(String input) {
    return input
        .toLowerCase()
        // Strip punctuation (keep apostrophes for contractions)
        .replaceAll(RegExp(r"[^\w\s']"), '')
        // Collapse whitespace
        .split(RegExp(r'\s+'))
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty && !_fillerWords.contains(w))
        .toList();
  }

  // ── Filler-word list ────────────────────────────────────────────────────────

  // Common STT injection words and spoken filler words to ignore
  static const _fillerWords = <String>{
    'um', 'uh', 'like', 'so', 'well', 'okay', 'ok', 'right',
    'ah', 'er', 'hmm', 'mm',
  };

  // ── Proper-noun alias map ───────────────────────────────────────────────────
  // Maps what the STT engine commonly hears → what the text actually says.
  // Add curriculum-specific terms here as they are discovered.
  static const Map<String, String> _aliases = {
    // Geography / Bible proper nouns
    'asians': 'ephesians',
    'philippians': 'philippians',   // often correct, but keep
    'collisions': 'colossians',
    'collision': 'colossians',
    'the lotions': 'colossians',
    'thessalonians': 'thessalonians',
    'galatians': 'galatians',
    'corinthians': 'corinthians',
    'deuteronomy': 'deuteronomy',
    'leviticus': 'leviticus',
    'numbers': 'numbers',
    // Common mishearings of short words
    'gods': 'god\'s',
    'jehovah': 'lord',             // some translations interchangeable
    // Latin / classical
    'logos': 'logos',
    'in principio': 'in the beginning', // Latin equivalent
  };

  static String _applyAliases(String word) {
    return _aliases[word] ?? word;
  }
}

// ── Data class ──────────────────────────────────────────────────────────────

class WordMatch {
  final String word;
  final bool matched;
  const WordMatch({required this.word, required this.matched});
}
