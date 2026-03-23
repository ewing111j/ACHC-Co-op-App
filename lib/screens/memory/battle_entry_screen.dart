import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/memory_provider.dart';
import '../../utils/app_theme.dart';
import 'battle_screen.dart';

class BattleEntryScreen extends StatefulWidget {
  final UserModel user;
  const BattleEntryScreen({super.key, required this.user});

  @override
  State<BattleEntryScreen> createState() => _BattleEntryScreenState();
}

class _BattleEntryScreenState extends State<BattleEntryScreen> {
  String _difficulty = 'standard';

  String get _enemyName {
    final unit = context.read<MemoryProvider>().currentUnit;
    if (unit <= 8) return 'Fog Sprites';
    if (unit <= 18) return 'The Forgetting Wraith';
    if (unit <= 25) return 'The Fog Knight';
    return 'The Archon of Oblivion';
  }

  String get _enemyEmoji {
    final unit = context.read<MemoryProvider>().currentUnit;
    if (unit <= 8) return '👻';
    if (unit <= 18) return '🌫️';
    if (unit <= 25) return '⚔️';
    return '🌑';
  }

  int get _enemyOrbs {
    final unit = context.read<MemoryProvider>().currentUnit;
    if (unit <= 8) return 3;
    if (unit <= 18) return 4;
    if (unit <= 25) return 5;
    return 6;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<MemoryProvider>();
    final unlocked = provider.currentUnit >= 4;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        title: const Text('Battle Mode'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: !unlocked
          ? _LockedView(currentUnit: provider.currentUnit)
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  Text(_enemyEmoji, style: const TextStyle(fontSize: 72)),
                  const SizedBox(height: 12),
                  Text(
                    _enemyName,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.navy,
                    ),
                  ),
                  Text(
                    '$_enemyOrbs orbs of health',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 32),
                  // Difficulty
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Difficulty',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                  const SizedBox(height: 10),
                  _DifficultyTile(
                    title: 'Gentle',
                    subtitle: '7 hearts · This unit only · Cloze Level 1',
                    value: 'gentle',
                    groupValue: _difficulty,
                    onChanged: (v) => setState(() => _difficulty = v!),
                  ),
                  _DifficultyTile(
                    title: 'Standard',
                    subtitle: '5 hearts · All studied units · Cloze Level 2',
                    value: 'standard',
                    groupValue: _difficulty,
                    onChanged: (v) => setState(() => _difficulty = v!),
                  ),
                  _DifficultyTile(
                    title: "Scholar's Trial",
                    subtitle: '3 hearts · All units · Cloze Level 3',
                    value: 'scholars',
                    groupValue: _difficulty,
                    onChanged: (v) => setState(() => _difficulty = v!),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BattleScreen(
                            user: widget.user,
                            difficulty: _difficulty,
                            enemyName: _enemyName,
                            enemyEmoji: _enemyEmoji,
                            enemyOrbs: _enemyOrbs,
                          ),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.gold,
                        foregroundColor: AppTheme.navy,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Enter Battle',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

class _LockedView extends StatelessWidget {
  final int currentUnit;
  const _LockedView({required this.currentUnit});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Battle Mode Locked',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete Unit 4 to unlock Battle Mode.\nCurrently on Unit $currentUnit.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

class _DifficultyTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String value;
  final String groupValue;
  final ValueChanged<String?> onChanged;

  const _DifficultyTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return RadioListTile<String>(
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      activeColor: AppTheme.navy,
      contentPadding: EdgeInsets.zero,
    );
  }
}
