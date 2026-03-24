// lib/screens/coverage/report_absence_sheet.dart
// Bottom sheet for a mentor to report their own absence.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import '../../models/coverage_models.dart';
import '../../models/user_model.dart';
import '../../services/coverage_service.dart';
import '../../utils/app_theme.dart';

class ReportAbsenceSheet extends StatefulWidget {
  final UserModel mentor;
  const ReportAbsenceSheet({super.key, required this.mentor});

  @override
  State<ReportAbsenceSheet> createState() => _ReportAbsenceSheetState();
}

class _ReportAbsenceSheetState extends State<ReportAbsenceSheet> {
  final _formKey = GlobalKey<FormState>();
  final _classController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _absenceDate = DateTime.now().add(const Duration(days: 1));
  String _period = 'All Day';
  bool _saving = false;
  final _service = CoverageService();

  static const _periods = ['AM', 'PM', 'All Day'];

  @override
  void dispose() {
    _classController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final absence = MentorAbsenceModel(
        id: const Uuid().v4(),
        mentorUid: widget.mentor.uid,
        mentorName: widget.mentor.displayName,
        className: _classController.text.trim(),
        classId: '',
        absenceDate: _absenceDate,
        period: _period,
        notes: _notesController.text.trim(),
        status: AbsenceStatus.pending,
        createdAt: DateTime.now(),
      );
      await _service.reportAbsence(absence);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Absence reported — the team has been notified.'),
              backgroundColor: AppTheme.classesColor),
        );
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _absenceDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (picked != null) setState(() => _absenceDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${_absenceDate.month}/${_absenceDate.day}/${_absenceDate.year}';
    return Container(
      margin: const EdgeInsets.only(top: 60),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Report Absence',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.navyDark)),
                  const SizedBox(height: 4),
                  Text('Reporting as ${widget.mentor.displayName}',
                      style: const TextStyle(
                          color: AppTheme.textHint, fontSize: 13)),
                  const SizedBox(height: 20),

                  // Class name
                  TextFormField(
                    controller: _classController,
                    decoration: const InputDecoration(
                      labelText: 'Class Name',
                      hintText: 'e.g. Latin I, Biology Lab',
                      prefixIcon: Icon(Icons.class_),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Please enter the class name'
                            : null,
                  ),
                  const SizedBox(height: 16),

                  // Date picker row
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                          labelText: 'Absence Date',
                          prefixIcon: Icon(Icons.calendar_today)),
                      child: Text(dateStr),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Period chips
                  const Text('Period',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  const SizedBox(height: 6),
                  Row(
                    children: _periods
                        .map(
                          (p) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(p),
                              selected: _period == p,
                              selectedColor:
                                  AppTheme.classesColor.withValues(alpha: 0.2),
                              onSelected: (_) =>
                                  setState(() => _period = p),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),

                  // Notes
                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      hintText:
                          'Lesson plan location, materials needed, etc.',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.notes),
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.classesColor,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      onPressed: _saving ? null : _submit,
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                          : const Text('Submit Absence Report',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .slideY(begin: 0.2, end: 0, duration: 300.ms, curve: Curves.easeOut)
        .fadeIn(duration: 250.ms);
  }
}
