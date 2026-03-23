import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../models/memory/memory_models.dart';
import '../../providers/memory_provider.dart';
import '../../utils/app_theme.dart';

class MemoryWorkSettingsScreen extends StatefulWidget {
  final UserModel user;
  const MemoryWorkSettingsScreen({super.key, required this.user});

  @override
  State<MemoryWorkSettingsScreen> createState() =>
      _MemoryWorkSettingsScreenState();
}

class _MemoryWorkSettingsScreenState extends State<MemoryWorkSettingsScreen> {
  late String _activeCycleId;
  late int _currentUnit;
  bool _saving = false;

  final _cycleOptions = ['cycle_1', 'cycle_2', 'cycle_3'];

  @override
  void initState() {
    super.initState();
    final provider = context.read<MemoryProvider>();
    _activeCycleId = provider.activeCycleId;
    _currentUnit = provider.currentUnit;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final provider = context.read<MemoryProvider>();
    await provider.saveSettings(MemorySettings(
      activeCycleId: _activeCycleId,
      currentUnit: _currentUnit,
    ));
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
    }
  }

  Future<void> _onCycleChanged(String? newCycle) async {
    if (newCycle == null || newCycle == _activeCycleId) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Change Active Cycle?'),
        content: const Text(
          'Warning: All student progress and Lumen states for the current cycle '
          'will be archived. This cannot be undone. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirm Change',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _activeCycleId = newCycle);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        title: const Text('Memory Work Settings'),
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
            const Text('Active Cycle',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _activeCycleId,
              items: _cycleOptions
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c.replaceAll('_', ' ').toUpperCase()),
                      ))
                  .toList(),
              onChanged: _onCycleChanged,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Current Unit',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _currentUnit,
              items: List.generate(
                30,
                (i) => DropdownMenuItem(
                  value: i + 1,
                  child: Text('Unit ${i + 1}'),
                ),
              ),
              onChanged: (v) {
                if (v != null) setState(() => _currentUnit = v);
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.navy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Save Settings',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
