import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../models/memory/memory_models.dart';
import '../../providers/memory_provider.dart';
import '../../utils/app_theme.dart';
import 'cloze_text_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DrillSessionScreen
// ─────────────────────────────────────────────────────────────────────────────

class DrillSessionScreen extends StatefulWidget {
  final UserModel user;
  final String filter;
  final int clozeLevel;

  const DrillSessionScreen({
    super.key,
    required this.user,
    required this.filter,
    required this.clozeLevel,
  });

  @override
  State<DrillSessionScreen> createState() => _DrillSessionScreenState();
}

class _DrillSessionScreenState extends State<DrillSessionScreen> {
  List<MemoryItemModel> _queue = [];
  List<MemoryItemModel> _missed = [];
  int _index = 0;
  bool _loading = true;
  bool _allRevealed = false;
  int _gotItCount = 0;
  int _totalWpEarned = 0;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final provider = context.read<MemoryProvider>();
    final subjects = provider.subjects;
    List<MemoryItemModel> items = [];

    for (final s in subjects) {
      if (widget.filter == 'this_unit' || widget.filter == 'random') {
        final fetched = await provider.loadMemoryItems(
          subjectId: s.id,
          unitNumber: provider.currentUnit,
        );
        items.addAll(fetched);
      } else {
        // all units this cycle
        for (int u = 1; u <= provider.currentUnit; u++) {
          final fetched = await provider.loadMemoryItems(
            subjectId: s.id,
            unitNumber: u,
          );
          items.addAll(fetched);
        }
      }
    }

    items.shuffle();
    if (mounted) {
      setState(() {
        _queue = items;
        _loading = false;
      });
    }
  }

  void _rate(int level) async {
    if (_index >= _queue.length) return;
    final item = _queue[_index];

    if (level == 1) {
      // Missed — push back into queue
      _missed.add(item);
    } else if (level == 3) {
      _gotItCount++;
    }

    final wpMap = {1: 0, 2: 5, 3: 10};
    final wp = wpMap[level] ?? 0;
    _totalWpEarned += wp;

    await context.read<MemoryProvider>().updateProgress(
      memoryItemId: item.id,
      masteryLevel: level,
      wpEarned: wp,
      sungPlayedFirst: false,
    );

    setState(() {
      _allRevealed = false;
      _index++;
    });

    if (_index >= _queue.length) {
      _showSummary();
    }
  }

  void _showSummary() {
    // Bonus WP for completing drill with 10+ cards
    if (_queue.length >= 10) {
      _totalWpEarned += 20;
      context.read<MemoryProvider>().awardWP(20);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Drill Complete! 🎉',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SummaryRow('Cards mastered', '$_gotItCount'),
            _SummaryRow('Needs review', '${_missed.length}'),
            _SummaryRow('WP earned', '+$_totalWpEarned WP'),
          ],
        ),
        actions: [
          if (_missed.isNotEmpty)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _queue = [..._missed];
                  _missed = [];
                  _index = 0;
                });
              },
              child: const Text('Retry Missed'),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // back to setup
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_queue.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppTheme.navy,
          foregroundColor: Colors.white,
          title: const Text('Drill'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: Text('No content available for this filter.')),
      );
    }

    final current = _index < _queue.length ? _queue[_index] : null;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        title: Text('Drill · ${_index + 1} / ${_queue.length}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Progress bar
          LinearProgressIndicator(
            value: _queue.isNotEmpty ? _index / _queue.length : 0,
            backgroundColor: Colors.grey[200],
            color: AppTheme.navy,
            minHeight: 4,
          ),
          if (current != null)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (current.questionText != null) ...[
                              Text(
                                current.questionText!,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Divider(height: 20),
                            ],
                            ClozeTextWidget(
                              text: current.contentText,
                              clozeLevel: widget.clozeLevel,
                              itemId: current.id,
                              onAllRevealed: () =>
                                  setState(() => _allRevealed = true),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_allRevealed || widget.clozeLevel == 0) ...[
                      Row(
                        children: [
                          Expanded(
                            child: _DrillRateButton(
                              label: 'Missed',
                              color: Colors.red[400]!,
                              onTap: () => _rate(1),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _DrillRateButton(
                              label: 'Almost',
                              color: Colors.orange[400]!,
                              onTap: () => _rate(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _DrillRateButton(
                              label: 'Got It!',
                              color: Colors.green[600]!,
                              onTap: () => _rate(3),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        'Tap blanks to reveal, then rate yourself',
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DrillRateButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _DrillRateButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
