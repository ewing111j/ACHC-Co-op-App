// lib/screens/classes/add_class_sheet.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../models/class_models.dart';
import '../../utils/app_theme.dart';

class AddClassSheet extends StatefulWidget {
  final UserModel user;
  final FirebaseFirestore db;
  final ClassModel? editClass; // null = create new
  const AddClassSheet({super.key, required this.user, required this.db, this.editClass});

  @override
  State<AddClassSheet> createState() => _AddClassSheetState();
}

class _AddClassSheetState extends State<AddClassSheet> {
  final _nameCtrl = TextEditingController();
  final _shortnameCtrl = TextEditingController();
  DateTime? _startDate;
  int _colorValue = kClassColorOptions[0];
  String _gradingMode = 'complete';
  bool _gradebookSimple = false;
  bool _saving = false;

  bool get _isEdit => widget.editClass != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final c = widget.editClass!;
      _nameCtrl.text = c.name;
      _shortnameCtrl.text = c.shortname;
      _startDate = c.startDate;
      _colorValue = c.colorValue;
      _gradingMode = c.gradingMode;
      _gradebookSimple = c.gradebookSimple;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _shortnameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(_isEdit ? 'Edit Class' : 'Add Class',
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ]),
              const SizedBox(height: 14),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Class Name *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _shortnameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Short Name (e.g. PHY, ENG)',
                    border: OutlineInputBorder()),
                maxLength: 8,
              ),
              const SizedBox(height: 4),
              // Start date
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _startDate == null
                      ? 'Start Date (optional)'
                      : 'Start: ${DateFormat('MMM d, y').format(_startDate!)}',
                  style: const TextStyle(fontSize: 14),
                ),
                trailing: const Icon(Icons.calendar_today, size: 18, color: AppTheme.navy),
                onTap: () async {
                  final p = await showDatePicker(
                    context: context,
                    initialDate: _startDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (p != null) setState(() => _startDate = p);
                },
              ),
              const Divider(),
              // Color picker
              const Text('Class Color',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: kClassColorOptions.map((c) {
                  final selected = c == _colorValue;
                  return GestureDetector(
                    onTap: () => setState(() => _colorValue = c),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(color: AppTheme.gold, width: 2.5)
                            : null,
                        boxShadow: selected
                            ? [BoxShadow(color: Color(c).withValues(alpha: 0.4),
                                blurRadius: 6)]
                            : null,
                      ),
                      child: selected
                          ? const Icon(Icons.check, color: Colors.white, size: 16)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              const Divider(),
              // Grading mode
              const Text('Default Grading Mode',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary)),
              Row(children: [
                Expanded(
                  child: RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Complete / Incomplete', style: TextStyle(fontSize: 13)),
                    value: 'complete',
                    groupValue: _gradingMode,
                    activeColor: AppTheme.classesColor,
                    onChanged: (v) => setState(() => _gradingMode = v!),
                  ),
                ),
              ]),
              Row(children: [
                Expanded(
                  child: RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Percentage (0–100%)', style: TextStyle(fontSize: 13)),
                    value: 'percent',
                    groupValue: _gradingMode,
                    activeColor: AppTheme.classesColor,
                    onChanged: (v) => setState(() => _gradingMode = v!),
                  ),
                ),
              ]),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Gradebook: show only Complete/Incomplete',
                    style: TextStyle(fontSize: 13)),
                subtitle: const Text('Recommended for 6th grade and younger',
                    style: TextStyle(fontSize: 11, color: AppTheme.textHint)),
                value: _gradebookSimple,
                activeColor: AppTheme.classesColor,
                onChanged: (v) => setState(() => _gradebookSimple = v ?? false),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.classesColor,
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: _saving
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      : Text(_isEdit ? 'Save Changes' : 'Create Class'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('Please enter a class name', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final shortname = _shortnameCtrl.text.trim().isEmpty
          ? name.substring(0, name.length > 4 ? 4 : name.length).toUpperCase()
          : _shortnameCtrl.text.trim().toUpperCase();

      if (_isEdit) {
        await widget.db.collection('classes').doc(widget.editClass!.id).update({
          'name': name,
          'shortname': shortname,
          'colorValue': _colorValue,
          'gradingMode': _gradingMode,
          'gradebookSimple': _gradebookSimple,
          if (_startDate != null) 'startDate': Timestamp.fromDate(_startDate!),
        });
      } else {
        final ref = widget.db.collection('classes').doc();
        final now = DateTime.now();
        await ref.set({
          'name': name,
          'shortname': shortname,
          'mentorUids': widget.user.canMentor ? [widget.user.uid] : [],
          'enrolledUids': [],
          'colorValue': _colorValue,
          'gradeLevel': '',
          'gradingMode': _gradingMode,
          'gradebookSimple': _gradebookSimple,
          'gradeA': 93.0,
          'gradeB': 85.0,
          'gradeC': 77.0,
          'gradeD': 70.0,
          'startDate': _startDate != null ? Timestamp.fromDate(_startDate!) : null,
          'schoolYearId': '${now.year}-${now.year + 1}',
          'isArchived': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        // Auto-generate weeks from admin calendar
        await _generateWeeks(ref.id);
      }
      if (mounted) Navigator.pop(context);
      if (mounted) _snack(_isEdit ? 'Class updated!' : 'Class created!');
    } catch (e) {
      _snack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _generateWeeks(String classId) async {
    try {
      // Pull admin calendar weeks
      final calSnap = await widget.db.collection('coopCalendar').get();
      if (calSnap.docs.isEmpty) return;
      final batch = widget.db.batch();
      int weekNum = 1;
      for (final doc in calSnap.docs) {
        // doc.id is "yyyy-MM-dd" (Monday)
        DateTime monday;
        try {
          monday = DateFormat('yyyy-MM-dd').parse(doc.id);
        } catch (_) {
          continue;
        }
        final sunday = monday.add(const Duration(days: 6));
        final label = doc.data()['label'] as String? ?? '';
        final isBreak = label.toLowerCase().contains('break') ||
            label.toLowerCase().contains('holiday');
        final weekRef = widget.db
            .collection('classes')
            .doc(classId)
            .collection('weeks')
            .doc(doc.id);
        batch.set(weekRef, {
          'classId': classId,
          'weekNumber': weekNum++,
          'calendarLabel': label,
          'weekStart': Timestamp.fromDate(monday),
          'weekEnd': Timestamp.fromDate(sunday),
          'isBreak': isBreak,
          'isHidden': false,
          'autoRevealDate': null,
          'notes': '',
        });
      }
      await batch.commit();
    } catch (_) {
      // Non-fatal: weeks can be generated manually
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppTheme.error : AppTheme.success,
      behavior: SnackBarBehavior.floating,
    ));
  }
}
