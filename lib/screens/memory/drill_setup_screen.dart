import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/memory_provider.dart';
import '../../utils/app_theme.dart';
import 'drill_session_screen.dart';

class DrillSetupScreen extends StatefulWidget {
  final UserModel user;
  const DrillSetupScreen({super.key, required this.user});

  @override
  State<DrillSetupScreen> createState() => _DrillSetupScreenState();
}

class _DrillSetupScreenState extends State<DrillSetupScreen> {
  String _filter = 'this_unit';
  int _clozeLevel = 3;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<MemoryProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        title: const Text('Drill Mode Setup'),
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
            const Text('Content Filter',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 10),
            _RadioOption(
              label: 'All Units This Cycle',
              value: 'all_cycle',
              groupValue: _filter,
              onChanged: (v) => setState(() => _filter = v!),
            ),
            _RadioOption(
              label: 'This Unit Only (Unit ${provider.currentUnit})',
              value: 'this_unit',
              groupValue: _filter,
              onChanged: (v) => setState(() => _filter = v!),
            ),
            _RadioOption(
              label: 'Random Mix',
              value: 'random',
              groupValue: _filter,
              onChanged: (v) => setState(() => _filter = v!),
            ),
            const SizedBox(height: 24),
            const Text('Cloze Level',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 10),
            Row(
              children: List.generate(4, (i) {
                final level = i + 1;
                final selected = _clozeLevel == level;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _clozeLevel = level),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? AppTheme.navy : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected ? AppTheme.navy : Colors.grey[300]!,
                        ),
                      ),
                      child: Text(
                        'Level $level',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : Colors.black54,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DrillSessionScreen(
                      user: widget.user,
                      filter: _filter,
                      clozeLevel: _clozeLevel,
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.navy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Start Drill',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _RadioOption extends StatelessWidget {
  final String label;
  final String value;
  final String groupValue;
  final ValueChanged<String?> onChanged;

  const _RadioOption({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return RadioListTile<String>(
      title: Text(label, style: const TextStyle(fontSize: 14)),
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      activeColor: AppTheme.navy,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }
}
