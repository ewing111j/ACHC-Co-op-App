import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../providers/memory_provider.dart';
import '../../providers/class_mode_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/battle_assets.dart';
import '../../widgets/lumen_home_panel.dart';
import 'battle_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ClassBattleEntryScreen
//
// Mentor-controlled class battle setup screen.
// Difficulty selector → launches ClassBattleScreen.
// ─────────────────────────────────────────────────────────────────────────────

class ClassBattleEntryScreen extends StatefulWidget {
  final UserModel user;
  const ClassBattleEntryScreen({super.key, required this.user});

  @override
  State<ClassBattleEntryScreen> createState() =>
      _ClassBattleEntryScreenState();
}

class _ClassBattleEntryScreenState extends State<ClassBattleEntryScreen> {
  String _difficulty = 'normal';

  static const _difficulties = [
    ('easy', 'Easy', 'Icons.sentiment_satisfied', '10 questions · Fog Sprites'),
    ('normal', 'Normal', 'Icons.bolt', '15 questions · Forgetting Wraiths'),
    ('hard', 'Hard', 'Icons.local_fire_department', '20 questions · Fog Knights'),
    ('legendary', 'Legendary', 'Icons.auto_awesome',
        '25 questions · Archon of Oblivion'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        title: const Text('Class Battle',
            style: TextStyle(fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.navy,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text('⚔️', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 8),
                  const Text(
                    'Class Battle Mode',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Face the enemies of forgetting together!',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Text(
              'Select Difficulty',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 12),

            // Difficulty options
            ...(_difficulties.map((d) {
              final (id, label, _, desc) = d;
              final selected = _difficulty == id;
              return GestureDetector(
                onTap: () => setState(() => _difficulty = id),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.navy.withValues(alpha: 0.08)
                        : Colors.white,
                    border: Border.all(
                      color: selected ? AppTheme.navy : Colors.grey[300]!,
                      width: selected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppTheme.navy
                              : Colors.grey[100],
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            id == 'easy'
                                ? '😊'
                                : id == 'normal'
                                    ? '⚡'
                                    : id == 'hard'
                                        ? '🔥'
                                        : '✨',
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: selected
                                      ? AppTheme.navy
                                      : Colors.black87,
                                )),
                            Text(desc,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600])),
                          ],
                        ),
                      ),
                      if (selected)
                        Icon(Icons.check_circle_rounded,
                            color: AppTheme.navy, size: 22),
                    ],
                  ),
                ),
              );
            })),

            const Spacer(),

            // Start button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ClassBattleScreen(
                      user: widget.user,
                      difficulty: _difficulty,
                    ),
                  ),
                ),
                icon: const Icon(Icons.flash_on, size: 22),
                label: const Text('Start Class Battle',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.gold,
                  foregroundColor: AppTheme.navy,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ClassBattleScreen
//
// The actual class battle. Reuses battle Q&A logic.
// Victory broadcasts +10 WP to all enrolled students.
// No WP penalty on defeat.
// ─────────────────────────────────────────────────────────────────────────────

class ClassBattleScreen extends StatefulWidget {
  final UserModel user;
  final String difficulty;

  const ClassBattleScreen({
    super.key,
    required this.user,
    required this.difficulty,
  });

  @override
  State<ClassBattleScreen> createState() => _ClassBattleScreenState();
}

class _ClassBattleScreenState extends State<ClassBattleScreen> {
  int _score = 0;
  int _totalQuestions = 0;
  int _questionIndex = 0;
  bool _battleEnded = false;
  bool _victory = false;
  bool _broadcasting = false;
  String? _broadcastResult;

  int get _targetScore {
    switch (widget.difficulty) {
      case 'easy':
        return 10;
      case 'hard':
        return 20;
      case 'legendary':
        return 25;
      default:
        return 15; // normal
    }
  }

  String get _enemyName {
    switch (widget.difficulty) {
      case 'easy':
        return 'Fog Sprite';
      case 'hard':
        return 'Fog Knight';
      case 'legendary':
        return 'Archon of Oblivion';
      default:
        return 'Forgetting Wraith';
    }
  }

  void _answerQuestion(bool correct) {
    if (_battleEnded) return;
    setState(() {
      _questionIndex++;
      if (correct) _score++;

      if (_questionIndex >= _targetScore) {
        _battleEnded = true;
        // Victory if ≥ 60% correct
        _victory = _score / _targetScore >= 0.6;
      }
    });
  }

  Future<void> _broadcastWP() async {
    setState(() => _broadcasting = true);
    final classModeProvider = context.read<ClassModeProvider>();
    final count = await classModeProvider.broadcastWP(wp: 10);
    setState(() {
      _broadcasting = false;
      _broadcastResult =
          '+10 WP awarded to $count student${count != 1 ? "s" : ""}!';
    });
  }

  void _exit() {
    final classModeProvider = context.read<ClassModeProvider>();
    classModeProvider.exitClassMode();
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    if (_battleEnded) {
      return _VictoryDefeatScreen(
        victory: _victory,
        score: _score,
        total: _targetScore,
        enemyName: _enemyName,
        broadcasting: _broadcasting,
        broadcastResult: _broadcastResult,
        onBroadcast: _victory && _broadcastResult == null
            ? _broadcastWP
            : null,
        onExit: _exit,
      );
    }

    return _BattleQuestionScreen(
      questionIndex: _questionIndex,
      totalQuestions: _targetScore,
      score: _score,
      enemyName: _enemyName,
      difficulty: widget.difficulty,
      onAnswer: _answerQuestion,
    );
  }
}

// ─── Question Screen ──────────────────────────────────────────────────────────

class _BattleQuestionScreen extends StatelessWidget {
  final int questionIndex;
  final int totalQuestions;
  final int score;
  final String enemyName;
  final String difficulty;
  final ValueChanged<bool> onAnswer;

  const _BattleQuestionScreen({
    required this.questionIndex,
    required this.totalQuestions,
    required this.score,
    required this.enemyName,
    required this.difficulty,
    required this.onAnswer,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (questionIndex / totalQuestions).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Class Battle · $enemyName',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Progress bar
            Row(
              children: [
                Text('$questionIndex / $totalQuestions',
                    style: const TextStyle(color: Colors.white70)),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white24,
                      color: AppTheme.gold,
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('$score pts',
                    style:
                        TextStyle(color: AppTheme.gold, fontWeight: FontWeight.w700)),
              ],
            ),

            const Spacer(),

            // Battle header: Lumen (class variant) vs Enemy
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    Consumer<MemoryProvider>(
                      builder: (context, provider, _) => LumenHomePanel(
                        level: provider.lumenState?.lumenLevel ?? 3,
                        isClassBattle: true,
                        width: 80,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text('Lumen',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const Text('VS',
                    style: TextStyle(
                        color: AppTheme.gold,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2)),
                Column(
                  children: [
                    SizedBox(
                      height: 80,
                      width: 80,
                      child: Image.asset(
                        BattleAssets.enemyImageForDifficulty(difficulty),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Text(
                          _enemyEmoji(difficulty),
                          style: const TextStyle(fontSize: 64),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      enemyName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),

            const Spacer(),

            // Q&A prompt (simplified — replace with actual content items when available)
            Consumer<MemoryProvider>(builder: (context, provider, _) {
              final item = _pickQuestion(provider, questionIndex);
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Text(
                  item ?? 'Ready to answer?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 17, height: 1.5),
                ),
              );
            }),

            const SizedBox(height: 24),

            // Answer buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => onAnswer(false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Not Yet',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => onAnswer(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Got It!',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String? _pickQuestion(MemoryProvider provider, int index) {
    if (provider.subjects.isEmpty) return null;
    final subjectIdx = index % provider.subjects.length;
    return 'Recite the content for ${provider.subjects[subjectIdx].name}';
  }

  String _enemyEmoji(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return '👻';
      case 'hard':
        return '🗡️';
      case 'legendary':
        return '👁️';
      default:
        return '🌫️';
    }
  }
}

// ─── Victory / Defeat Screen ──────────────────────────────────────────────────

class _VictoryDefeatScreen extends StatelessWidget {
  final bool victory;
  final int score;
  final int total;
  final String enemyName;
  final bool broadcasting;
  final String? broadcastResult;
  final VoidCallback? onBroadcast;
  final VoidCallback onExit;

  const _VictoryDefeatScreen({
    required this.victory,
    required this.score,
    required this.total,
    required this.enemyName,
    required this.broadcasting,
    required this.broadcastResult,
    required this.onBroadcast,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: victory ? const Color(0xFF0D2B1E) : const Color(0xFF2B0D0D),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                victory ? '🏆' : '💀',
                style: const TextStyle(fontSize: 80),
              ),
              const SizedBox(height: 16),
              Text(
                victory ? 'Victory!' : 'Defeated!',
                style: TextStyle(
                  color: victory ? AppTheme.gold : Colors.red[300],
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                victory
                    ? 'The class defeated the $enemyName!'
                    : 'The $enemyName was too powerful this time.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 16),
              Text(
                'Score: $score / $total',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700),
              ),

              const SizedBox(height: 32),

              // WP broadcast button (victory only)
              if (victory) ...[
                if (broadcastResult != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppTheme.gold.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      '⭐ $broadcastResult',
                      style: TextStyle(
                          color: AppTheme.gold,
                          fontSize: 16,
                          fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: broadcasting ? null : onBroadcast,
                      icon: broadcasting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.stars_rounded, size: 22),
                      label: Text(
                        broadcasting
                            ? 'Awarding WP...'
                            : 'Award +10 WP to All Students',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.gold,
                        foregroundColor: AppTheme.navy,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
              ],

              // Exit button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: onExit,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Exit Class Mode',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
