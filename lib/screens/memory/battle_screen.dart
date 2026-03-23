import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../models/memory/memory_models.dart';
import '../../providers/memory_provider.dart';
import '../../utils/app_theme.dart';
import 'cloze_text_widget.dart';

class BattleScreen extends StatefulWidget {
  final UserModel user;
  final String difficulty;
  final String enemyName;
  final String enemyEmoji;
  final int enemyOrbs;

  const BattleScreen({
    super.key,
    required this.user,
    required this.difficulty,
    required this.enemyName,
    required this.enemyEmoji,
    required this.enemyOrbs,
  });

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  List<MemoryItemModel> _cards = [];
  int _index = 0;
  bool _loading = true;
  bool _allRevealed = false;
  late int _lumenHearts;
  late int _enemyOrbs;

  int get _clozeLevel {
    switch (widget.difficulty) {
      case 'gentle':
        return 1;
      case 'scholars':
        return 3;
      default:
        return 2;
    }
  }

  @override
  void initState() {
    super.initState();
    _lumenHearts = widget.difficulty == 'gentle'
        ? 7
        : widget.difficulty == 'scholars'
            ? 3
            : 5;
    _enemyOrbs = widget.enemyOrbs;
    _loadCards();
  }

  Future<void> _loadCards() async {
    final provider = context.read<MemoryProvider>();
    final subjects = provider.subjects;
    final List<MemoryItemModel> items = [];

    for (final s in subjects) {
      final maxUnit = widget.difficulty == 'gentle'
          ? provider.currentUnit
          : provider.currentUnit;
      for (int u = 1; u <= maxUnit; u++) {
        final fetched = await provider.loadMemoryItems(
          subjectId: s.id,
          unitNumber: u,
        );
        items.addAll(fetched);
      }
    }
    items.shuffle();

    if (mounted) {
      setState(() {
        _cards = items;
        _loading = false;
      });
    }
  }

  void _onRate(int level) async {
    // level: 1=missed, 2=almost, 3=nailed
    setState(() {
      if (level == 1) {
        _lumenHearts = (_lumenHearts - 1).clamp(0, 99);
      } else if (level == 3) {
        _enemyOrbs = (_enemyOrbs - 1).clamp(0, 99);
      }
      _allRevealed = false;
      _index++;
    });

    if (_enemyOrbs == 0) {
      await _onVictory();
    } else if (_lumenHearts == 0) {
      _onDefeat();
    } else if (_index >= _cards.length) {
      _onDefeat(); // ran out of cards
    }
  }

  Future<void> _onVictory() async {
    // +30 WP for win
    await context.read<MemoryProvider>().awardWP(30);
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('⭐ Victory!',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🎉 You defeated the enemy!',
                style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Text('+30 Wisdom Points earned!',
                style: TextStyle(color: Colors.orange)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.navy,
              foregroundColor: Colors.white,
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _onDefeat() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Lumen retreats...'),
        content: const Text(
          'Keep studying and try again!',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_cards.isEmpty || _index >= _cards.length) {
      return const Scaffold(
          body: Center(child: Text('No content available for battle.')));
    }

    final card = _cards[_index];

    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        title: const Text('KNOWLEDGE BATTLE',
            style: TextStyle(fontSize: 14, letterSpacing: 1.5)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Battle header: Lumen vs Enemy
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Lumen
                Expanded(
                  child: Column(
                    children: [
                      const Text('🕯️', style: TextStyle(fontSize: 36)),
                      const Text('Lumen',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_lumenHearts, (_) =>
                          const Text('❤️', style: TextStyle(fontSize: 14))),
                      ),
                    ],
                  ),
                ),
                const Text('⚡',
                    style: TextStyle(fontSize: 28, color: Colors.white)),
                // Enemy
                Expanded(
                  child: Column(
                    children: [
                      Text(widget.enemyEmoji,
                          style: const TextStyle(fontSize: 36)),
                      Text(widget.enemyName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_enemyOrbs, (_) =>
                          const Text('🔮', style: TextStyle(fontSize: 14))),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Card
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${_index + 1} / ${_cards.length}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      textAlign: TextAlign.right,
                    ),
                    if (card.questionText != null) ...[
                      Text(
                        card.questionText!,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      const Divider(height: 20),
                    ],
                    ClozeTextWidget(
                      text: card.contentText,
                      clozeLevel: _clozeLevel,
                      itemId: card.id,
                      onAllRevealed: () =>
                          setState(() => _allRevealed = true),
                    ),
                    const SizedBox(height: 20),
                    if (_allRevealed || _clozeLevel == 0) ...[
                      Row(
                        children: [
                          Expanded(
                            child: _BattleButton(
                              label: 'Missed',
                              color: Colors.red[400]!,
                              onTap: () => _onRate(1),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _BattleButton(
                              label: 'Almost',
                              color: Colors.orange[400]!,
                              onTap: () => _onRate(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _BattleButton(
                              label: 'Nailed!',
                              color: Colors.green[600]!,
                              onTap: () => _onRate(3),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        'Tap blanks to reveal',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BattleButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _BattleButton(
      {required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
    );
  }
}
