import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

// ─── Level Constants ──────────────────────────────────────────────────────────
const int kClozeLevel0 = 0; // Full text
const int kClozeLevel1 = 1; // ~20% blanked
const int kClozeLevel2 = 2; // ~50% blanked
const int kClozeLevel3 = 3; // ~80% blanked
const int kClozeLevel4 = 4; // 100% blanked

// Function words never blanked at lower levels
final Set<String> _functionWords = {
  'the', 'a', 'an', 'in', 'of', 'and', 'or', 'but', 'to', 'for',
  'with', 'by', 'as', 'at', 'from', 'on', 'is', 'are', 'was', 'were',
  'be', 'been', 'being', 'have', 'has', 'had', 'do', 'does', 'did',
  'will', 'would', 'could', 'should', 'may', 'might', 'shall', 'can',
  'not', 'no', 'it', 'its', 'this', 'that', 'these', 'those', 'he',
  'she', 'they', 'we', 'i', 'you', 'his', 'her', 'their', 'our',
  'my', 'your', 'into', 'onto', 'over', 'under', 'about',
  'after', 'before', 'between', 'through', 'during', 'without',
  'also', 'then', 'than', 'so', 'if', 'when', 'where', 'who', 'which',
  'what', 'all', 'each', 'both', 'any', 'some', 'such',
};

/// Returns a list of booleans: true = this word should be blanked.
/// [text] is the text to process, [level] is 0-4.
List<bool> getBlankedWords(String text, int level) {
  if (level == 0) {
    // Full text — nothing blanked
    final words = _tokenize(text);
    return List.filled(words.length, false);
  }

  final words = _tokenize(text);
  if (words.isEmpty) return [];

  final n = words.length;
  final blanked = List.filled(n, false);

  // Identify sentence starts (after period, exclamation, question mark)
  final sentenceStarts = <int>{0};
  for (int i = 0; i < words.length; i++) {
    final w = words[i];
    if (w.endsWith('.') || w.endsWith('!') || w.endsWith('?')) {
      if (i + 1 < n) sentenceStarts.add(i + 1);
    }
  }

  // Classify each word
  final isContentWord = List.generate(n, (i) {
    if (sentenceStarts.contains(i)) return false; // never blank first word
    final clean = words[i].replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
    if (clean.isEmpty) return false;
    // Numbers are high-priority content words
    if (RegExp(r'^\d').hasMatch(clean)) return true;
    // Proper nouns (capitalized mid-sentence) — high priority
    if (words[i][0] == words[i][0].toUpperCase() &&
        words[i][0] != words[i][0].toLowerCase() &&
        !sentenceStarts.contains(i)) return true;
    // Function word check
    if (_functionWords.contains(clean)) return false;
    return true;
  });

  // Build priority list: numbers+proper first, then other content, then function
  final priority1 = <int>[]; // numbers + proper nouns
  final priority2 = <int>[]; // other content words
  final priority3 = <int>[]; // function words (only blanked at level 4)

  for (int i = 0; i < n; i++) {
    if (sentenceStarts.contains(i)) continue;
    final clean = words[i].replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
    if (clean.isEmpty) continue;
    if (RegExp(r'^\d').hasMatch(clean)) {
      priority1.add(i);
    } else if (words[i][0] == words[i][0].toUpperCase() &&
        words[i][0] != words[i][0].toLowerCase()) {
      priority1.add(i);
    } else if (isContentWord[i]) {
      priority2.add(i);
    } else {
      priority3.add(i);
    }
  }

  // Determine how many to blank
  final totalBlankable = priority1.length + priority2.length;
  int targetBlanks;
  switch (level) {
    case 1:
      targetBlanks = (n * 0.20).round().clamp(0, totalBlankable);
      break;
    case 2:
      targetBlanks = (n * 0.50).round().clamp(0, totalBlankable);
      break;
    case 3:
      targetBlanks = (n * 0.80).round().clamp(0, totalBlankable);
      break;
    case 4:
      // Blank everything except sentence starts
      for (int i = 0; i < n; i++) {
        if (!sentenceStarts.contains(i)) blanked[i] = true;
      }
      return blanked;
    default:
      return blanked;
  }

  // Fill blanks by priority
  int filled = 0;
  for (final i in priority1) {
    if (filled >= targetBlanks) break;
    blanked[i] = true;
    filled++;
  }
  for (final i in priority2) {
    if (filled >= targetBlanks) break;
    blanked[i] = true;
    filled++;
  }

  return blanked;
}

List<String> _tokenize(String text) =>
    text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

// ─── ClozeTextWidget ──────────────────────────────────────────────────────────

class ClozeTextWidget extends StatefulWidget {
  final String text;
  final int clozeLevel;
  final String itemId; // resets reveal state when this changes
  final TextStyle? textStyle;
  final VoidCallback? onAllRevealed;

  const ClozeTextWidget({
    super.key,
    required this.text,
    required this.clozeLevel,
    required this.itemId,
    this.textStyle,
    this.onAllRevealed,
  });

  @override
  State<ClozeTextWidget> createState() => _ClozeTextWidgetState();
}

class _ClozeTextWidgetState extends State<ClozeTextWidget> {
  late List<String> _words;
  late List<bool> _blanked;
  late List<bool> _revealed;
  bool _allRevealed = false;

  @override
  void initState() {
    super.initState();
    _rebuild();
  }

  @override
  void didUpdateWidget(ClozeTextWidget old) {
    super.didUpdateWidget(old);
    if (old.itemId != widget.itemId || old.clozeLevel != widget.clozeLevel) {
      _rebuild();
    }
  }

  void _rebuild() {
    _words = _tokenize(widget.text);
    _blanked = getBlankedWords(widget.text, widget.clozeLevel);
    _revealed = List.filled(_words.length, false);
    _allRevealed = false;
  }

  void _revealAll() {
    setState(() {
      _revealed = List.filled(_words.length, true);
      _allRevealed = true;
    });
    widget.onAllRevealed?.call();
  }

  void _revealWord(int index) {
    setState(() {
      _revealed[index] = true;
      if (_blanked.every((b) => !b) ||
          _words.asMap().entries
              .where((e) => _blanked[e.key])
              .every((e) => _revealed[e.key])) {
        _allRevealed = true;
        widget.onAllRevealed?.call();
      }
    });
  }

  bool get allBlanksRevealed {
    if (_allRevealed) return true;
    for (int i = 0; i < _words.length; i++) {
      if (_blanked[i] && !_revealed[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = widget.textStyle ??
        const TextStyle(fontSize: 16, height: 1.6, color: Colors.black87);

    final spans = <InlineSpan>[];
    for (int i = 0; i < _words.length; i++) {
      if (i > 0) spans.add(const TextSpan(text: ' '));

      if (_blanked[i] && !_revealed[i]) {
        spans.add(_BlankSpan(
          word: _words[i],
          onTap: () => _revealWord(i),
        ));
      } else if (_blanked[i] && _revealed[i]) {
        // Revealed word — show in gold
        spans.add(TextSpan(
          text: _words[i],
          style: baseStyle.copyWith(
            color: AppTheme.gold,
            fontWeight: FontWeight.w600,
          ),
        ));
      } else {
        spans.add(TextSpan(text: _words[i], style: baseStyle));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(text: TextSpan(children: spans)),
        if (widget.clozeLevel > 0) ...[
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _allRevealed ? null : _revealAll,
            icon: Icon(
              Icons.visibility_outlined,
              size: 16,
              color: _allRevealed ? Colors.grey : AppTheme.navy,
            ),
            label: Text(
              _allRevealed ? 'All revealed' : 'Reveal All',
              style: TextStyle(
                color: _allRevealed ? Colors.grey : AppTheme.navy,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A single blank tile with tap-to-reveal animation
class _BlankSpan extends WidgetSpan {
  _BlankSpan({required String word, required VoidCallback onTap})
      : super(
          alignment: PlaceholderAlignment.middle,
          child: _BlankTile(word: word, onTap: onTap),
        );
}

class _BlankTile extends StatefulWidget {
  final String word;
  final VoidCallback onTap;

  const _BlankTile({required this.word, required this.onTap});

  @override
  State<_BlankTile> createState() => _BlankTileState();
}

class _BlankTileState extends State<_BlankTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scale = Tween(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Width proportional to word length, min 24, max 100
    final width = (widget.word.length * 9.0).clamp(24.0, 100.0);

    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: width,
          height: 22,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: AppTheme.gold,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

// ─── Level Selector Widget ────────────────────────────────────────────────────

class ClozeLevelSelector extends StatelessWidget {
  final int selectedLevel;
  final ValueChanged<int> onChanged;

  static const List<String> _labels = ['Full', '1', '2', '3', 'Solo'];

  const ClozeLevelSelector({
    super.key,
    required this.selectedLevel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) {
          final selected = i == selectedLevel;
          return GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? AppTheme.navy : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _labels[i],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : Colors.black54,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
