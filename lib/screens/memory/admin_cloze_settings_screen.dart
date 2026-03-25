// lib/screens/memory/admin_cloze_settings_screen.dart
// P2-5: Admin/Mentor UI to set class-wide cloze level overrides.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../models/memory/memory_models.dart';
import '../../providers/memory_provider.dart';
import '../../providers/class_mode_provider.dart';
import '../../services/cloze_override_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_animations.dart';
import 'cloze_text_widget.dart';

class AdminClozeSettingsScreen extends StatefulWidget {
  final UserModel user;
  const AdminClozeSettingsScreen({super.key, required this.user});

  @override
  State<AdminClozeSettingsScreen> createState() =>
      _AdminClozeSettingsScreenState();
}

class _AdminClozeSettingsScreenState extends State<AdminClozeSettingsScreen> {
  final _service = ClozeOverrideService();

  String? _selectedClassId;
  SubjectModel? _selectedSubject;
  String _selectedUnitId = 'all'; // 'all' or unit number as string
  int _previewLevel = 2;
  bool _saving = false;

  // Sample text for the preview ClozeTextWidget
  static const _previewText =
      'The quick brown fox jumps over the lazy dog near the riverbank.';

  @override
  void initState() {
    super.initState();
    final classProv = context.read<ClassModeProvider>();
    _selectedClassId = classProv.currentClassId ?? widget.user.mentorClassIds.firstOrNull;
  }

  List<UnitModel> get _units {
    final memProv = context.read<MemoryProvider>();
    return memProv.units;
  }

  @override
  Widget build(BuildContext context) {
    final memProv = context.watch<MemoryProvider>();
    final subjects = memProv.subjects;
    final classProv = context.watch<ClassModeProvider>();

    // Build class list for picker
    final classIds = widget.user.isAdmin
        ? null // admin sees all — would need a full classes fetch; use current
        : widget.user.mentorClassIds;
    final effectiveClassIds = classIds ?? (classProv.currentClassId != null
        ? [classProv.currentClassId!]
        : <String>[]);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.navyDark,
        foregroundColor: Colors.white,
        title: const Text('Cloze Level Overrides',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (_selectedClassId != null)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear all overrides for this class',
              onPressed: _confirmClearAll,
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Picker Section ─────────────────────────────────────────────────
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Class picker (if multiple classes)
                if (effectiveClassIds.length > 1) ...[
                  _label('Class'),
                  DropdownButtonFormField<String>(
                    value: _selectedClassId,
                    decoration: _inputDeco('Select class'),
                    items: effectiveClassIds
                        .map((id) => DropdownMenuItem(
                            value: id, child: Text(id)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedClassId = v),
                  ),
                  const SizedBox(height: 12),
                ] else if (effectiveClassIds.isNotEmpty &&
                    _selectedClassId == null) ...[
                  // Auto-select single class
                  Builder(builder: (_) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_selectedClassId == null) {
                        setState(() => _selectedClassId = effectiveClassIds.first);
                      }
                    });
                    return const SizedBox.shrink();
                  }),
                ],

                // Subject picker
                _label('Subject'),
                DropdownButtonFormField<SubjectModel>(
                  value: _selectedSubject,
                  decoration: _inputDeco('Select subject'),
                  items: subjects
                      .map((s) => DropdownMenuItem(
                          value: s, child: Text(s.name)))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _selectedSubject = v;
                    _selectedUnitId = 'all';
                  }),
                ),
                const SizedBox(height: 12),

                // Unit picker
                _label('Unit (or All Units)'),
                DropdownButtonFormField<String>(
                  value: _selectedUnitId,
                  decoration: _inputDeco('Unit'),
                  items: [
                    const DropdownMenuItem(
                        value: 'all', child: Text('All Units')),
                    ..._units
                        .where((u) =>
                            _selectedSubject == null ||
                            u.cycleId == memProv.activeCycleId)
                        .map((u) => DropdownMenuItem(
                            value: u.unitNumber.toString(),
                            child: Text('Unit ${u.unitNumber} — ${u.label}')))
                  ],
                  onChanged: (v) => setState(() => _selectedUnitId = v ?? 'all'),
                ),
              ],
            ),
          ).animate().fadeIn(duration: AppAnimations.cardFadeInDuration),

          // ── Level Slider ────────────────────────────────────────────────────
          Container(
            color: AppTheme.surface,
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _label('Cloze Level'),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.navy,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Level $_previewLevel',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14),
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _previewLevel.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  activeColor: AppTheme.navy,
                  label: 'Level $_previewLevel',
                  onChanged: (v) => setState(() => _previewLevel = v.round()),
                ),
                const SizedBox(height: 8),
                // Preview
                const Text('Preview:',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: ClozeTextWidget(
                    text: _previewText,
                    clozeLevel: _previewLevel,
                    itemId: 'preview',
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(
              duration: AppAnimations.cardFadeInDuration,
              delay: AppAnimations.staggerItemDelay),

          // ── Save / Clear Buttons ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectedClassId == null ||
                            _selectedSubject == null ||
                            _saving
                        ? null
                        : _clearOverride,
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear Override'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      side: BorderSide(color: AppTheme.error),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _selectedClassId == null ||
                            _selectedSubject == null ||
                            _saving
                        ? null
                        : _saveOverride,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_outlined),
                    label: const Text('Save Override'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.navy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Existing Overrides List ─────────────────────────────────────
          Expanded(
            child: _selectedClassId == null
                ? const Center(child: Text('Select a class to see overrides'))
                : StreamBuilder<List<ClozeOverrideModel>>(
                    stream: _service.overridesForClass(_selectedClassId!),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }
                      final items = snap.data ?? [];
                      if (items.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.tune_outlined,
                                  size: 48,
                                  color: AppTheme.textTertiary),
                              const SizedBox(height: 12),
                              const Text('No overrides set',
                                  style: TextStyle(
                                      color: AppTheme.textSecondary)),
                            ],
                          ),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, i) =>
                            _OverrideTile(
                          item: items[i],
                          onClear: () => _service.clearOverride(
                            classId: items[i].classId,
                            subjectId: items[i].subjectId,
                            unitId: items[i].unitId,
                          ),
                        ).animate().fadeIn(
                            duration: AppAnimations.cardFadeInDuration,
                            delay: Duration(
                                milliseconds:
                                    i * AppAnimations.staggerItemDelay.inMilliseconds)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveOverride() async {
    if (_selectedClassId == null || _selectedSubject == null) return;
    setState(() => _saving = true);
    try {
      await _service.setOverride(ClozeOverrideModel(
        classId: _selectedClassId!,
        subjectId: _selectedSubject!.id,
        unitId: _selectedUnitId,
        level: _previewLevel,
        setBy: widget.user.uid,
        setAt: DateTime.now(),
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Override saved: ${_selectedSubject!.name} '
              '${_selectedUnitId == 'all' ? '(all units)' : 'Unit $_selectedUnitId'} '
              '→ Level $_previewLevel',
            ),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clearOverride() async {
    if (_selectedClassId == null || _selectedSubject == null) return;
    setState(() => _saving = true);
    try {
      await _service.clearOverride(
        classId: _selectedClassId!,
        subjectId: _selectedSubject!.id,
        unitId: _selectedUnitId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Override cleared')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmClearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear All Overrides?'),
        content: const Text(
            'This will remove all cloze overrides for this class. Students will revert to their personal cloze level settings.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Clear All',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true && _selectedClassId != null) {
      await _service.clearAllForClass(_selectedClassId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All overrides cleared')),
        );
      }
    }
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary)),
      );

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.cardBorder),
        ),
        filled: true,
        fillColor: AppTheme.surfaceVariant,
      );
}

// ── Override Tile ──────────────────────────────────────────────────────────────
class _OverrideTile extends StatelessWidget {
  final ClozeOverrideModel item;
  final VoidCallback onClear;

  const _OverrideTile({required this.item, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.navy.withValues(alpha: 0.1),
            ),
            child: Center(
              child: Text(
                '${item.level}',
                style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppTheme.navy,
                    fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.subjectId} · ${item.unitId == 'all' ? 'All Units' : 'Unit ${item.unitId}'}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: AppTheme.navyDark),
                ),
                Text(
                  'Set ${DateFormat('MMM d').format(item.setAt)}',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary),
                ),
                if (item.note != null && item.note!.isNotEmpty)
                  Text(item.note!,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textTertiary,
                          fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.error),
            onPressed: onClear,
            tooltip: 'Remove override',
          ),
        ],
      ),
    );
  }
}
