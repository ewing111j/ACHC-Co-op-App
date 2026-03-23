// lib/screens/classes/homework_sheet.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import '../../models/user_model.dart';
import '../../models/class_models.dart';
import '../../utils/app_theme.dart';

// ── Add/Edit Homework Bottom Sheet ──────────────────────────────────────────

class HomeworkSheet extends StatefulWidget {
  final ClassModel classModel;
  final ClassWeekModel week;
  final UserModel user;
  final FirebaseFirestore db;
  final HomeworkModel? editHw; // null = add new
  final SubmissionModel? existingSubmission; // for student quick-submit
  final VoidCallback? onSubmissionChanged;
  const HomeworkSheet({
    super.key,
    required this.classModel,
    required this.week,
    required this.user,
    required this.db,
    this.editHw,
    this.existingSubmission,
    this.onSubmissionChanged,
  });

  @override
  State<HomeworkSheet> createState() => _HomeworkSheetState();
}

class _HomeworkSheetState extends State<HomeworkSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _maxPtsCtrl = TextEditingController();
  final _checklistCtrl = TextEditingController();
  final _contentUrlCtrl = TextEditingController();
  final _videoUrlCtrl = TextEditingController();
  DateTime? _dueDate;
  String _gradingMode = 'complete'; // 'complete' | 'percent'
  String _itemType = 'hw'; // 'hw' | 'quiz' | 'test' | 'content'
  List<String> _checklist = [];
  bool _saving = false;
  bool _isEdit = false;

  @override
  void initState() {
    super.initState();
    final hw = widget.editHw;
    _isEdit = hw != null;
    if (hw != null) {
      _titleCtrl.text = hw.title;
      _descCtrl.text = hw.description;
      _dueDate = hw.dueDate;
      _gradingMode = hw.gradingMode;
      _itemType = hw.itemType.isEmpty ? 'hw' : hw.itemType;
      _checklist = List<String>.from(hw.checklist);
      if (hw.maxPoints != null) _maxPtsCtrl.text = hw.maxPoints!.toString();
      if (hw.contentUrl != null) _contentUrlCtrl.text = hw.contentUrl!;
      if (hw.videoUrl != null) _videoUrlCtrl.text = hw.videoUrl!;
    } else {
      _dueDate = widget.week.weekEnd;
      _gradingMode = widget.classModel.gradingMode;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _maxPtsCtrl.dispose();
    _checklistCtrl.dispose();
    _contentUrlCtrl.dispose();
    _videoUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? widget.week.weekEnd,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  void _addChecklistItem() {
    final text = _checklistCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _checklist.add(text);
      _checklistCtrl.clear();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dueDate == null) {
      _snack('Please select a due date', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final colRef = widget.db
          .collection('classes')
          .doc(widget.classModel.id)
          .collection('weeks')
          .doc(widget.week.id)
          .collection('homework');

      final maxPts = _gradingMode == 'percent' && _maxPtsCtrl.text.isNotEmpty
          ? double.tryParse(_maxPtsCtrl.text)
          : null;

      final contentUrl = _contentUrlCtrl.text.trim();
      final videoUrl = _videoUrlCtrl.text.trim();
      final isContent = _itemType == 'content';

      final data = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'classId': widget.classModel.id,
        'weekId': widget.week.id,
        'dueDate': Timestamp.fromDate(_dueDate!),
        'gradingMode': isContent ? 'complete' : _gradingMode,
        'maxPoints': (!isContent) ? maxPts : null,
        'checklist': _checklist,
        'itemType': _itemType,
        if (contentUrl.isNotEmpty) 'contentUrl': contentUrl,
        if (videoUrl.isNotEmpty) 'videoUrl': videoUrl,
        'order': _isEdit ? widget.editHw!.order : DateTime.now().millisecondsSinceEpoch,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_isEdit) {
        await colRef.doc(widget.editHw!.id).update(data);
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        await colRef.add(data);
      }

      if (mounted) {
        Navigator.pop(context);
        final typeLabel = _itemType == 'content' ? 'Content'
            : _itemType == 'quiz' ? 'Quiz'
            : _itemType == 'test' ? 'Test'
            : 'Homework';
        _snack(_isEdit ? '$typeLabel updated' : '$typeLabel added');
      }
    } catch (e) {
      _snack('Error saving homework: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Homework'),
        content: Text('Delete "${widget.editHw!.title}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.db
          .collection('classes')
          .doc(widget.classModel.id)
          .collection('weeks')
          .doc(widget.week.id)
          .collection('homework')
          .doc(widget.editHw!.id)
          .delete();
      if (mounted) {
        Navigator.pop(context);
        _snack('Homework deleted');
      }
    } catch (e) {
      _snack('Error deleting: $e', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppTheme.error : AppTheme.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, ctrl) => Form(
          key: _formKey,
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppTheme.dividerColor,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isEdit
                            ? 'Edit ${_itemType == 'content' ? 'Content' : _itemType == 'quiz' ? 'Quiz' : _itemType == 'test' ? 'Test' : 'Homework'}'
                            : 'Add Item',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold,
                            color: AppTheme.navy),
                      ),
                    ),
                    if (_isEdit)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: _delete,
                      ),
                  ],
                ),
              ),
              AppTheme.goldDivider(),
              // Body
              Expanded(
                child: ListView(
                  controller: ctrl,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // ── Item Type Selector ──────────────────────────
                    const Text('Item Type',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.navy)),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _TypeChip(
                            label: 'Homework',
                            icon: Icons.book_outlined,
                            value: 'hw',
                            selected: _itemType == 'hw',
                            color: AppTheme.assignmentsColor,
                            onTap: () => setState(() {
                              _itemType = 'hw';
                              if (_gradingMode == 'complete' && widget.classModel.gradingMode == 'percent') {
                                _gradingMode = 'percent';
                              }
                            }),
                          ),
                          const SizedBox(width: 8),
                          _TypeChip(
                            label: 'Quiz',
                            icon: Icons.quiz_outlined,
                            value: 'quiz',
                            selected: _itemType == 'quiz',
                            color: AppTheme.classesColor,
                            onTap: () => setState(() {
                              _itemType = 'quiz';
                              _gradingMode = 'percent';
                            }),
                          ),
                          const SizedBox(width: 8),
                          _TypeChip(
                            label: 'Test',
                            icon: Icons.fact_check_outlined,
                            value: 'test',
                            selected: _itemType == 'test',
                            color: AppTheme.mandatoryRed,
                            onTap: () => setState(() {
                              _itemType = 'test';
                              _gradingMode = 'percent';
                            }),
                          ),
                          const SizedBox(width: 8),
                          _TypeChip(
                            label: 'Content',
                            icon: Icons.article_outlined,
                            value: 'content',
                            selected: _itemType == 'content',
                            color: Colors.teal,
                            onTap: () => setState(() {
                              _itemType = 'content';
                              _gradingMode = 'complete';
                            }),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Title
                    TextFormField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Title *',
                        prefixIcon: Icon(Icons.book_outlined, size: 18),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    // Description
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description / Instructions',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.notes, size: 18),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Due date
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(10),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Due Date *',
                          prefixIcon: Icon(Icons.calendar_today, size: 18),
                        ),
                        child: Text(
                          _dueDate != null
                              ? DateFormat('MMM d, yyyy').format(_dueDate!)
                              : 'Tap to select',
                          style: TextStyle(
                              fontSize: 14,
                              color: _dueDate != null
                                  ? AppTheme.textPrimary
                                  : AppTheme.textTertiary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Grading mode (not for content)
                    if (_itemType != 'content') ...[
                      Row(
                        children: [
                          const Icon(Icons.grade_outlined, size: 18, color: AppTheme.textSecondary),
                          const SizedBox(width: 8),
                          const Text('Grading:',
                              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                          const SizedBox(width: 12),
                          ChoiceChip(
                            label: const Text('Complete'),
                            selected: _gradingMode == 'complete',
                            onSelected: (_) => setState(() => _gradingMode = 'complete'),
                            selectedColor: AppTheme.classesColor.withValues(alpha: 0.2),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Percentage'),
                            selected: _gradingMode == 'percent',
                            onSelected: (_) => setState(() => _gradingMode = 'percent'),
                            selectedColor: AppTheme.classesColor.withValues(alpha: 0.2),
                          ),
                        ],
                      ),
                      if (_gradingMode == 'percent') ...[
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _maxPtsCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Max Points (optional)',
                            prefixIcon: Icon(Icons.score, size: 18),
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 14),
                    // Content URL fields (for content type)
                    if (_itemType == 'content') ...[
                      const Text('Content Link (optional)',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.navy)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _contentUrlCtrl,
                        decoration: const InputDecoration(
                          hintText: 'https://…',
                          prefixIcon: Icon(Icons.link, size: 18),
                          labelText: 'Link / URL',
                        ),
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _videoUrlCtrl,
                        decoration: const InputDecoration(
                          hintText: 'YouTube embed URL…',
                          prefixIcon: Icon(Icons.video_library_outlined, size: 18),
                          labelText: 'Video URL (embed)',
                        ),
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 14),
                    ],
                    const SizedBox(height: 6),
                    // Checklist builder
                    const Text('Checklist Items (optional)',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.navy)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _checklistCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Add a checklist item…',
                              isDense: true,
                            ),
                            onFieldSubmitted: (_) => _addChecklistItem(),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline,
                              color: AppTheme.navy),
                          onPressed: _addChecklistItem,
                        ),
                      ],
                    ),
                    ..._checklist.asMap().entries.map((e) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.check_circle_outline,
                              size: 16, color: AppTheme.textSecondary),
                          title: Text(e.value, style: const TextStyle(fontSize: 13)),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () =>
                                setState(() => _checklist.removeAt(e.key)),
                          ),
                        )),
                    const SizedBox(height: 30),
                    // Save button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save_outlined),
                        label: Text(_isEdit ? 'Save Changes'
                            : _itemType == 'content' ? 'Add Content'
                            : _itemType == 'quiz' ? 'Add Quiz'
                            : _itemType == 'test' ? 'Add Test'
                            : 'Add Homework'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.navy,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Homework Detail / Submission View ────────────────────────────────────────

class HomeworkDetailSheet extends StatefulWidget {
  final HomeworkModel hw;
  final ClassModel classModel;
  final ClassWeekModel week;
  final UserModel user;
  final FirebaseFirestore db;
  final SubmissionModel? existingSubmission;
  const HomeworkDetailSheet({
    super.key,
    required this.hw,
    required this.classModel,
    required this.week,
    required this.user,
    required this.db,
    this.existingSubmission,
  });

  @override
  State<HomeworkDetailSheet> createState() => _HomeworkDetailSheetState();
}

class _HomeworkDetailSheetState extends State<HomeworkDetailSheet> {
  late Map<String, bool> _checklist;
  late String _status;
  String? _fileUrl;
  String? _fileName;
  bool _uploading = false;
  bool _saving = false;
  SubmissionModel? _sub;
  double? _gradeInput;
  final _feedbackCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sub = widget.existingSubmission;
    _status = _sub?.status ?? 'pending';
    _fileUrl = _sub?.fileUrl;
    _fileName = _sub?.fileName;
    _feedbackCtrl.text = _sub?.feedback ?? '';
    // Init checklist: merge hw items with sub's done map
    final hwList = widget.hw.checklist;
    final doneMap = _sub?.checklistDone ?? {};
    _checklist = {for (final item in hwList) item: doneMap[item] ?? false};
    _gradeInput = _sub?.grade;
  }

  @override
  void dispose() {
    _feedbackCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(withData: kIsWeb);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    setState(() => _uploading = true);
    try {
      final path = 'class_submissions/${widget.classModel.id}/${widget.hw.id}/${widget.user.uid}_${file.name}';
      final ref = FirebaseStorage.instance.ref(path);
      if (kIsWeb && file.bytes != null) {
        await ref.putData(file.bytes!);
      }
      final url = await ref.getDownloadURL();
      setState(() {
        _fileUrl = url;
        _fileName = file.name;
        _uploading = false;
      });
    } catch (e) {
      setState(() => _uploading = false);
      _snack('Upload failed: $e', error: true);
    }
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final allDone = _checklist.values.every((v) => v);
      final newStatus = allDone ? 'submitted' : 'pending';
      final colRef = widget.db
          .collection('classes')
          .doc(widget.classModel.id)
          .collection('weeks')
          .doc(widget.week.id)
          .collection('homework')
          .doc(widget.hw.id)
          .collection('submissions');

      final cl = <String, bool>{};
      _checklist.forEach((k, v) => cl[k] = v);

      final data = <String, dynamic>{
        'homeworkId': widget.hw.id,
        'classId': widget.classModel.id,
        'weekId': widget.week.id,
        'studentUid': widget.user.uid,
        'studentName': widget.user.displayName,
        'status': newStatus,
        'fileUrl': _fileUrl,
        'fileName': _fileName,
        'checklistDone': cl,
        'submittedAt': FieldValue.serverTimestamp(),
      };

      if (_sub != null) {
        await colRef.doc(_sub!.id).update(data);
      } else {
        await colRef.add(data);
      }

      if (mounted) {
        Navigator.pop(context);
        _snack(newStatus == 'submitted' ? 'Marked complete!' : 'Progress saved');
      }
    } catch (e) {
      _snack('Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _gradeSubmission() async {
    // Mentor/admin grades a submission
    if (_sub == null) return;
    try {
      await widget.db
          .collection('classes')
          .doc(widget.classModel.id)
          .collection('weeks')
          .doc(widget.week.id)
          .collection('homework')
          .doc(widget.hw.id)
          .collection('submissions')
          .doc(_sub!.id)
          .update({
        'grade': _gradeInput,
        'feedback': _feedbackCtrl.text.trim(),
        'status': 'graded',
        'gradedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        Navigator.pop(context);
        _snack('Graded!');
      }
    } catch (e) {
      _snack('Error grading: $e', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppTheme.error : AppTheme.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final hw = widget.hw;
    final user = widget.user;
    final canGrade = user.canMentor || user.isAdmin;
    final isStudent = user.isStudent;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, ctrl) => Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: AppTheme.dividerColor,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(hw.title,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.navy)),
                  ),
                  _StatusBadge(status: _status),
                ],
              ),
            ),
            AppTheme.goldDivider(),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.all(20),
                children: [
                  // Due date
                  Row(children: [
                    const Icon(Icons.calendar_today, size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      'Due: ${DateFormat('MMM d, yyyy').format(hw.dueDate)}',
                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ]),
                  if (hw.description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(hw.description,
                        style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
                  ],

                  // Checklist
                  if (hw.checklist.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('Checklist',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.navy)),
                    const SizedBox(height: 6),
                    ...hw.checklist.map((item) => CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(item, style: const TextStyle(fontSize: 13)),
                          value: _checklist[item] ?? false,
                          onChanged: isStudent
                              ? (v) => setState(() => _checklist[item] = v ?? false)
                              : null,
                        )),
                  ],

                  // File upload (student)
                  if (isStudent) ...[
                    const SizedBox(height: 16),
                    const Text('Submission',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.navy)),
                    const SizedBox(height: 8),
                    if (_fileName != null)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.attach_file, size: 18, color: AppTheme.navy),
                        title: Text(_fileName!, style: const TextStyle(fontSize: 13)),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => setState(() {
                            _fileUrl = null;
                            _fileName = null;
                          }),
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: _uploading ? null : _pickAndUpload,
                      icon: _uploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.upload_file, size: 18),
                      label: Text(_uploading ? 'Uploading…' : 'Attach File'),
                    ),
                  ],

                  // Grading (mentor/admin)
                  if (canGrade && _sub != null) ...[
                    const SizedBox(height: 20),
                    const Divider(),
                    const Text('Grade Submission',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.navy)),
                    const SizedBox(height: 8),
                    if (hw.gradingMode == 'percent')
                      TextFormField(
                        initialValue: _gradeInput?.toString(),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: hw.maxPoints != null
                              ? 'Points (max ${hw.maxPoints})'
                              : 'Percentage',
                          prefixIcon: const Icon(Icons.grade, size: 18),
                        ),
                        onChanged: (v) =>
                            _gradeInput = double.tryParse(v),
                      ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _feedbackCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Feedback',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _gradeSubmission,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Save Grade'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.navy,
                            foregroundColor: Colors.white),
                      ),
                    ),
                  ],

                  // Mark complete button (student)
                  if (isStudent) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _submit,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check),
                        label: const Text('Submit / Mark Complete'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.classesColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'submitted':
        color = Colors.green;
        label = 'Submitted';
        break;
      case 'graded':
        color = AppTheme.navy;
        label = 'Graded';
        break;
      case 'overdue':
        color = Colors.red;
        label = 'Overdue';
        break;
      default:
        color = Colors.orange;
        label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4))),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Item type chip for HomeworkSheet ─────────────────────────────────────────
class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _TypeChip({
    required this.label,
    required this.icon,
    required this.value,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : AppTheme.cardBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: selected ? color : AppTheme.textSecondary),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? color : AppTheme.textSecondary)),
        ]),
      ),
    );
  }
}
